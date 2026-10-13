// Isolated PostgreSQL WASM tests; no remote database is accessed.
// npm install --prefix .dart_tool/sql-tests @electric-sql/pglite
// node test/sql/preorders.mjs
import { PGlite } from '../../.dart_tool/sql-tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync, readdirSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
await db.exec(`create role anon; create role authenticated; create role service_role;
 create schema auth;
 create table auth.users(id uuid primary key, email text, raw_user_meta_data jsonb default '{}', raw_app_meta_data jsonb default '{}');
 create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
 grant usage on schema public, auth to anon, authenticated, service_role;
 grant execute on function auth.uid() to anon, authenticated;`);
for (const file of readdirSync('supabase/migrations').filter(f => f.endsWith('.sql')).sort()) {
  // gen_random_uuid is built-in; the production pgcrypto extension is unused here.
  const sql = readFileSync(`supabase/migrations/${file}`, 'utf8').replace('create extension if not exists pgcrypto;', '');
  await db.exec(sql);
  console.log(`Applied ${file}`);
}
const admin = '00000000-0000-0000-0000-000000000001';
const barista = '00000000-0000-0000-0000-000000000002';
await db.exec(`insert into auth.users(id,email,raw_app_meta_data) values
 ('${admin}','admin@test.local','{"role":"admin"}'), ('${barista}','barista@test.local','{"role":"barista"}');
 insert into public.categories values ('test-cat','Test',999);
 insert into public.products(id,category_id,name,price,stock_remaining) values ('test-food','test-cat','Test food',100,3);`);
async function actor(uid = '', role = 'authenticated') { await db.exec(`reset role; set test.uid = '${uid}'; set role ${role}`); }
async function scalar(sql, params = []) { return (await db.query(sql, params)).rows[0].value; }
async function reject(sql, params, message) { await assert.rejects(db.query(sql, params), message); }
await actor(admin);
await db.query(`select save_pickup_slot(now() + interval '2 hours', now() + interval '1 hour', 3)`);
const slots = await scalar('select list_pickup_slots() as value');
const slot = slots[0].id;
const createSQL = `select create_order($1::jsonb,'','pay_on_pickup','Тест','Клиент',$2::uuid) as value`;
const item = qty => JSON.stringify([{productId:'test-food',qty,modifiers:[]}]);
await actor('', 'anon');
const order = await scalar(createSQL, [item(2), slot]);
assert.match(order.qrCodeData, /^techcafe:pickup:/);
assert.ok(order.pickupAt);
const publicOrder = await scalar('select get_order_by_key($1) as value',[order.orderId]);
assert.equal(publicOrder.qrCodeData, undefined);
assert.equal(publicOrder.pickup_token, undefined);
await reject(createSQL, [item(2), slot], /недостаточно мест/);
await reject(`select create_order_core($1::jsonb,'','pay_on_pickup','Тест','Клиент')`,[item(1)],/permission denied/);
await reject('select make_order_created_json($1)', [order.orderId], /permission denied/);
await reject('select set_product_stock($1,100)', ['test-food'], /permission denied/);
await reject('select list_pickup_slots(true)', [], /Требуется вход/);
await reject('select claim_order_push()', [], /permission denied/);
await actor(admin);
await db.query('select update_order_status($1, $2)', [order.orderId,'canceled']);
await db.query('select update_order_status($1, $2)', [order.orderId,'canceled']);
assert.equal((await scalar('select list_pickup_slots() as value'))[0].remaining, 3);
await reject('select update_order_status($1, $2)',[order.orderId,'accepted'],/Недопустимый переход/);
await db.query(`select save_pickup_slot(now()+ interval '3 hours',now()+interval '2 hours',10)`);
const slot2 = (await scalar('select list_pickup_slots() as value'))[1].id;
await actor('', 'anon');
await reject(createSQL, [JSON.stringify([{productId:'test-food',qty:2},{productId:'test-food',qty:2}]), slot2], /Недостаточно порций/);
assert.equal((await scalar('select list_pickup_slots() as value'))[1].remaining, 10, 'stock failure rolls back capacity');
const full = await scalar(createSQL, [item(3), slot]);
const catalog = await scalar(`select list_products(null,false,null,null) as value`);
const products = Array.isArray(catalog) ? catalog : catalog.items;
assert.equal(products.find(p=>p.id==='test-food').isAvailable,false);
await db.query('select subscribe_order_push($1,$2)', [full.qrCodeData,'test-device-token-123456789']);
await reject('select subscribe_order_push($1,$2)', [full.orderId,'test-device-token-123456789'], /Активный заказ не найден/);
await actor(admin);
assert.equal((await scalar('select inspect_pickup_code($1) as value',[full.qrCodeData])).id,full.orderId);
await reject('select redeem_pickup_code($1,true)',[full.qrCodeData],/ещё не готов/);
for (const status of ['accepted','cooking','ready']) await db.query('select update_order_status($1,$2)',[full.orderId,status]);
await reject('select update_order_status($1,$2)',[full.orderId,'issued'],/по QR/);
await actor(barista);
await reject('select inspect_pickup_code($1)',[full.qrCodeData],/Недостаточно прав/);
await reject('select redeem_pickup_code($1,true)',[full.qrCodeData],/Недостаточно прав/);
await actor('', 'service_role');
const jobs = (await db.query('select * from claim_order_push()')).rows;
assert.equal(jobs.length,1);
assert.equal((await db.query('select * from claim_order_push()')).rows.length,0,'leased job is not reclaimed');
await db.query('select finish_order_push($1,$2,true)',[jobs[0].id,jobs[0].lease_id]);
await actor(admin);
await reject('select redeem_pickup_code($1,false)',[full.qrCodeData],/получение оплаты/);
const issued = await scalar('select redeem_pickup_code($1,true) as value',[full.qrCodeData]);
assert.equal(issued.status,'issued');
await reject('select redeem_pickup_code($1,true)',[full.qrCodeData],/уже выдан/);
await reject('select update_order_status($1,$2)',[full.orderId,'canceled'],/Недопустимый переход/);
await db.exec('reset role');
assert.equal(await scalar(`select stock_remaining as value from products where id='test-food'`),0);
assert.equal(await scalar(`select reserved as value from pickup_slots where id=$1`,[slot]),3);
await actor('', 'anon');
await reject('select * from staff_order_events', [], /permission denied/);
await reject('select poll_staff_order_events()', [], /permission denied/);
await actor('', 'authenticated');
assert.equal((await db.query('select * from staff_order_events')).rows.length, 0, 'no staff profile cannot read realtime journal');
await actor(admin);
const baseline = await scalar('select poll_staff_order_events() as value');
assert.deepEqual(baseline.events, [], 'initial subscription does not announce old orders');
await db.query('select set_product_stock($1,10)', ['test-food']);
await actor('', 'anon');
const liveOrder = await scalar(createSQL, [item(1), slot2]);
await actor(admin);
let cursor = baseline.cursor;
const liveEvents = [];
let more = true;
while (more) {
  const page = await scalar('select poll_staff_order_events($1,1) as value', [cursor]);
  assert.ok(page.cursor > cursor);
  liveEvents.push(...page.events);
  cursor = page.cursor;
  more = page.hasMore;
}
assert.equal(liveEvents.filter(e => e.kind === 'created').length, 1);
assert.equal(liveEvents[0].orderId, liveOrder.orderId);
assert.equal(liveEvents[0].order.items.length, 1, 'journal returns complete committed order including items');
assert.ok(!JSON.stringify(liveEvents).includes('pickup_token'));
assert.ok(!JSON.stringify(liveEvents).includes(liveOrder.qrCodeData));
await db.query('select update_order_status($1,$2)', [liveOrder.orderId,'accepted']);
const updatedEvents = await scalar('select poll_staff_order_events($1) as value', [cursor]);
assert.ok(updatedEvents.events.every(e => e.kind === 'updated'));
assert.equal(updatedEvents.events[0].order.status, 'accepted');
await actor(barista);
assert.ok((await db.query('select * from staff_order_events')).rows.length > 0);
await reject("insert into staff_order_events values(9999,'fake','created',now())", [], /permission denied/);
console.log('PASS: migrations, capacity, stock rollback, cancellation, roles, QR, push queue, realtime journal, cursor paging and secrecy');
await db.close();
