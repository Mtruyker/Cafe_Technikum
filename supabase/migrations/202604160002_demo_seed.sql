insert into public.categories (id, name, sort)
values
  ('cat_donuts', 'Пончики', 1),
  ('cat_pancakes', 'Блины', 2),
  ('cat_coffee', 'Кофе', 3)
on conflict (id) do update
set
  name = excluded.name,
  sort = excluded.sort;

insert into public.products (
  id,
  category_id,
  name,
  description,
  price,
  image_url,
  is_available
)
values
  (
    'donut_classic',
    'cat_donuts',
    'Пончик Классический',
    'Мягкий пончик с легкой ванильной глазурью.',
    120,
    'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=800',
    true
  ),
  (
    'donut_berry',
    'cat_donuts',
    'Пончик Ягодный',
    'Пончик с ягодной начинкой и легкой посыпкой.',
    140,
    'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800',
    true
  ),
  (
    'pancake_ham',
    'cat_pancakes',
    'Блин с ветчиной и сыром',
    'Сытный блин с ветчиной и сливочным сыром.',
    210,
    'https://images.unsplash.com/photo-1528207776546-365bb710ee93?w=800',
    true
  ),
  (
    'coffee_cappuccino',
    'cat_coffee',
    'Капучино',
    'Эспрессо с молочной пенкой.',
    160,
    'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800',
    true
  )
on conflict (id) do update
set
  category_id = excluded.category_id,
  name = excluded.name,
  description = excluded.description,
  price = excluded.price,
  image_url = excluded.image_url,
  is_available = excluded.is_available;

delete from public.modifier_items
where group_id in (
  'donut_glaze',
  'donut_topping',
  'pancake_fill',
  'coffee_size',
  'coffee_sugar',
  'coffee_syrup'
);

delete from public.modifier_groups
where id in (
  'donut_glaze',
  'donut_topping',
  'pancake_fill',
  'coffee_size',
  'coffee_sugar',
  'coffee_syrup'
);

insert into public.modifier_groups (
  id,
  product_id,
  name,
  min_val,
  max_val,
  position
)
values
  ('donut_glaze', 'donut_classic', 'Глазурь', 0, 1, 0),
  ('donut_topping', 'donut_berry', 'Посыпка', 0, 1, 0),
  ('pancake_fill', 'pancake_ham', 'Начинка', 1, 1, 0),
  ('coffee_size', 'coffee_cappuccino', 'Размер', 1, 1, 0),
  ('coffee_sugar', 'coffee_cappuccino', 'Сахар', 1, 1, 1),
  ('coffee_syrup', 'coffee_cappuccino', 'Сироп', 0, 1, 2);

insert into public.modifier_items (
  id,
  group_id,
  name,
  price_delta,
  position
)
values
  ('glaze_sugar', 'donut_glaze', 'Сахарная', 0, 0),
  ('glaze_choco', 'donut_glaze', 'Шоколадная', 20, 1),
  ('glaze_caramel', 'donut_glaze', 'Карамельная', 25, 2),
  ('top_none', 'donut_topping', 'Без посыпки', 0, 0),
  ('top_nuts', 'donut_topping', 'Орехи', 15, 1),
  ('top_coconut', 'donut_topping', 'Кокос', 10, 2),
  ('fill_ham_cheese', 'pancake_fill', 'Ветчина и сыр', 0, 0),
  ('fill_chicken_mushroom', 'pancake_fill', 'Курица и грибы', 30, 1),
  ('fill_cottage', 'pancake_fill', 'Творог', 20, 2),
  ('size_s', 'coffee_size', 'S', 0, 0),
  ('size_m', 'coffee_size', 'M', 30, 1),
  ('size_l', 'coffee_size', 'L', 60, 2),
  ('sugar_yes', 'coffee_sugar', 'С сахаром', 0, 0),
  ('sugar_no', 'coffee_sugar', 'Без сахара', 0, 1),
  ('syrup_none', 'coffee_syrup', 'Без сиропа', 0, 0),
  ('syrup_vanilla', 'coffee_syrup', 'Ваниль', 20, 1),
  ('syrup_hazelnut', 'coffee_syrup', 'Фундук', 20, 2);
