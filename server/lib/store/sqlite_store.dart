import 'package:sqlite3/sqlite3.dart';

import '../models/models.dart';

/// Persistent SQLite-backed store — drop-in replacement for [AppStore].
class SqliteStore {
  SqliteStore(String dbPath) : _db = sqlite3.open(dbPath) {
    _db.execute('PRAGMA journal_mode = WAL');
    _db.execute('PRAGMA foreign_keys = ON');
    _initSchema();
  }

  final Database _db;

  // ---------------------------------------------------------------------------
  // Schema
  // ---------------------------------------------------------------------------

  void _initSchema() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id   TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sort INTEGER NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id           TEXT PRIMARY KEY,
        category_id  TEXT NOT NULL,
        name         TEXT NOT NULL,
        description  TEXT NOT NULL DEFAULT '',
        price        REAL NOT NULL,
        image_url    TEXT NOT NULL DEFAULT '',
        is_available INTEGER NOT NULL DEFAULT 1
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS modifier_groups (
        id         TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        name       TEXT NOT NULL,
        min_val    INTEGER NOT NULL,
        max_val    INTEGER NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS modifier_items (
        id          TEXT PRIMARY KEY,
        group_id    TEXT NOT NULL,
        name        TEXT NOT NULL,
        price_delta REAL NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS staff (
        id   TEXT PRIMARY KEY,
        pin  TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id                  TEXT PRIMARY KEY,
        order_number        TEXT UNIQUE NOT NULL,
        created_at          TEXT NOT NULL,
        customer_first_name TEXT NOT NULL DEFAULT '',
        customer_last_name  TEXT NOT NULL DEFAULT '',
        status              TEXT NOT NULL,
        total               REAL NOT NULL,
        comment             TEXT,
        payment_method      TEXT NOT NULL,
        payment_status      TEXT NOT NULL,
        provider_payment_id TEXT,
        paid_at             TEXT
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id             TEXT PRIMARY KEY,
        order_id       TEXT NOT NULL,
        product_id     TEXT NOT NULL,
        name_snapshot  TEXT NOT NULL,
        price_snapshot REAL NOT NULL,
        qty            INTEGER NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS order_item_modifiers (
        rowid              INTEGER PRIMARY KEY,
        order_item_id      TEXT NOT NULL,
        name_snapshot      TEXT NOT NULL,
        price_delta_snapshot REAL NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id           TEXT PRIMARY KEY,
        order_id     TEXT NOT NULL,
        amount       REAL NOT NULL,
        status       TEXT NOT NULL,
        checkout_url TEXT NOT NULL,
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL
      )
    ''');

    _ensureColumn(
      tableName: 'orders',
      columnName: 'customer_first_name',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    _ensureColumn(
      tableName: 'orders',
      columnName: 'customer_last_name',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
  }

  void _ensureColumn({
    required String tableName,
    required String columnName,
    required String definition,
  }) {
    final columns = _db.select('PRAGMA table_info($tableName)');
    final hasColumn = columns.any((row) => row['name'] == columnName);
    if (hasColumn) {
      return;
    }

    _db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $definition');
  }

  // ---------------------------------------------------------------------------
  // Seed
  // ---------------------------------------------------------------------------

  void seedIfEmpty() {
    final result = _db.select('SELECT COUNT(*) AS cnt FROM categories');
    if ((result.first['cnt'] as int) > 0) return;

    _db.execute('BEGIN');
    try {
      // Categories
      _insertCategory(
        const Category(id: 'cat_donuts', name: 'Пончики', sort: 1),
      );
      _insertCategory(
        const Category(id: 'cat_pancakes', name: 'Блины', sort: 2),
      );
      _insertCategory(const Category(id: 'cat_coffee', name: 'Кофе', sort: 3));

      // Products + modifiers
      _insertProduct(
        Product(
          id: 'donut_classic',
          categoryId: 'cat_donuts',
          name: 'Пончик Классический',
          description: 'Мягкий пончик с легкой ванильной глазурью.',
          price: 120,
          imageUrl:
              'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=800',
          isAvailable: true,
          modifierGroups: const [
            ModifierGroup(
              id: 'donut_glaze',
              name: 'Глазурь',
              min: 0,
              max: 1,
              items: [
                ModifierItem(
                  id: 'glaze_sugar',
                  name: 'Сахарная',
                  priceDelta: 0,
                ),
                ModifierItem(
                  id: 'glaze_choco',
                  name: 'Шоколадная',
                  priceDelta: 20,
                ),
                ModifierItem(
                  id: 'glaze_caramel',
                  name: 'Карамельная',
                  priceDelta: 25,
                ),
              ],
            ),
          ],
        ),
      );

      _insertProduct(
        Product(
          id: 'donut_berry',
          categoryId: 'cat_donuts',
          name: 'Пончик Ягодный',
          description: 'Пончик с ягодной начинкой и легкой посыпкой.',
          price: 140,
          imageUrl:
              'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800',
          isAvailable: true,
          modifierGroups: const [
            ModifierGroup(
              id: 'donut_topping',
              name: 'Посыпка',
              min: 0,
              max: 1,
              items: [
                ModifierItem(
                  id: 'top_none',
                  name: 'Без посыпки',
                  priceDelta: 0,
                ),
                ModifierItem(id: 'top_nuts', name: 'Орехи', priceDelta: 15),
                ModifierItem(id: 'top_coconut', name: 'Кокос', priceDelta: 10),
              ],
            ),
          ],
        ),
      );

      _insertProduct(
        Product(
          id: 'pancake_ham',
          categoryId: 'cat_pancakes',
          name: 'Блин с ветчиной и сыром',
          description: 'Сытный блин с ветчиной и сливочным сыром.',
          price: 210,
          imageUrl:
              'https://images.unsplash.com/photo-1528207776546-365bb710ee93?w=800',
          isAvailable: true,
          modifierGroups: const [
            ModifierGroup(
              id: 'pancake_fill',
              name: 'Начинка',
              min: 1,
              max: 1,
              items: [
                ModifierItem(
                  id: 'fill_ham_cheese',
                  name: 'Ветчина и сыр',
                  priceDelta: 0,
                ),
                ModifierItem(
                  id: 'fill_chicken_mushroom',
                  name: 'Курица и грибы',
                  priceDelta: 30,
                ),
                ModifierItem(
                  id: 'fill_cottage',
                  name: 'Творог',
                  priceDelta: 20,
                ),
              ],
            ),
          ],
        ),
      );

      _insertProduct(
        Product(
          id: 'coffee_cappuccino',
          categoryId: 'cat_coffee',
          name: 'Капучино',
          description: 'Эспрессо с молочной пенкой.',
          price: 160,
          imageUrl:
              'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800',
          isAvailable: true,
          modifierGroups: const [
            ModifierGroup(
              id: 'coffee_size',
              name: 'Размер',
              min: 1,
              max: 1,
              items: [
                ModifierItem(id: 'size_s', name: 'S', priceDelta: 0),
                ModifierItem(id: 'size_m', name: 'M', priceDelta: 30),
                ModifierItem(id: 'size_l', name: 'L', priceDelta: 60),
              ],
            ),
            ModifierGroup(
              id: 'coffee_sugar',
              name: 'Сахар',
              min: 1,
              max: 1,
              items: [
                ModifierItem(id: 'sugar_yes', name: 'С сахаром', priceDelta: 0),
                ModifierItem(id: 'sugar_no', name: 'Без сахара', priceDelta: 0),
              ],
            ),
            ModifierGroup(
              id: 'coffee_syrup',
              name: 'Сироп',
              min: 0,
              max: 1,
              items: [
                ModifierItem(
                  id: 'syrup_none',
                  name: 'Без сиропа',
                  priceDelta: 0,
                ),
                ModifierItem(
                  id: 'syrup_vanilla',
                  name: 'Ваниль',
                  priceDelta: 20,
                ),
                ModifierItem(
                  id: 'syrup_hazelnut',
                  name: 'Фундук',
                  priceDelta: 20,
                ),
              ],
            ),
          ],
        ),
      );

      // Staff
      _insertStaff('stf_cashier', '1111', 'Cashier', 'cashier');
      _insertStaff('stf_barista', '2222', 'Barista', 'barista');
      _insertStaff('stf_admin', '9999', 'Admin', 'admin');

      // Order counter
      _db.execute(
        "INSERT OR IGNORE INTO meta (key, value) VALUES ('order_counter', '100')",
      );

      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _insertCategory(Category c) {
    _db.execute('INSERT INTO categories (id, name, sort) VALUES (?, ?, ?)', [
      c.id,
      c.name,
      c.sort,
    ]);
  }

  void _insertProduct(Product p) {
    _db.execute(
      'INSERT INTO products (id, category_id, name, description, price, image_url, is_available) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        p.id,
        p.categoryId,
        p.name,
        p.description,
        p.price,
        p.imageUrl,
        p.isAvailable ? 1 : 0,
      ],
    );
    for (final g in p.modifierGroups) {
      _db.execute(
        'INSERT INTO modifier_groups (id, product_id, name, min_val, max_val) VALUES (?, ?, ?, ?, ?)',
        [g.id, p.id, g.name, g.min, g.max],
      );
      for (final item in g.items) {
        _db.execute(
          'INSERT INTO modifier_items (id, group_id, name, price_delta) VALUES (?, ?, ?, ?)',
          [item.id, g.id, item.name, item.priceDelta],
        );
      }
    }
  }

  void _insertStaff(String id, String pin, String name, String role) {
    _db.execute('INSERT INTO staff (id, pin, name, role) VALUES (?, ?, ?, ?)', [
      id,
      pin,
      name,
      role,
    ]);
  }

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  List<Category> get categories {
    final rows = _db.select(
      'SELECT id, name, sort FROM categories ORDER BY sort',
    );
    return rows
        .map(
          (r) => Category(
            id: r['id'] as String,
            name: r['name'] as String,
            sort: r['sort'] as int,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Products  (Map-like wrapper)
  // ---------------------------------------------------------------------------

  late final ProductsMap products = ProductsMap._(_db);

  // ---------------------------------------------------------------------------
  // Staff  (Map-like wrapper keyed by PIN)
  // ---------------------------------------------------------------------------

  late final StaffMap staffByPin = StaffMap._(_db);

  // ---------------------------------------------------------------------------
  // Orders  (Map-like wrapper keyed by id)
  // ---------------------------------------------------------------------------

  late final OrdersMap ordersById = OrdersMap._(_db);

  CafeOrder? orderByNumber(String orderNumber) {
    final rows = _db.select('SELECT id FROM orders WHERE order_number = ?', [
      orderNumber,
    ]);
    if (rows.isEmpty) return null;
    return ordersById[rows.first['id'] as String];
  }

  String nextOrderNumber() {
    _db.execute('BEGIN');
    try {
      final rows = _db.select(
        "SELECT value FROM meta WHERE key = 'order_counter'",
      );
      final current = int.parse(rows.first['value'] as String);
      final next = current + 1;
      _db.execute("UPDATE meta SET value = ? WHERE key = 'order_counter'", [
        next.toString(),
      ]);
      _db.execute('COMMIT');
      return 'A-$next';
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void saveOrder(CafeOrder order) {
    _db.execute('BEGIN');
    try {
      // Upsert order row
      _db.execute(
        '''
        INSERT INTO orders (
          id,
          order_number,
          created_at,
          customer_first_name,
          customer_last_name,
          status,
          total,
          comment,
          payment_method,
          payment_status,
          provider_payment_id,
          paid_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          customer_first_name = excluded.customer_first_name,
          customer_last_name  = excluded.customer_last_name,
          status              = excluded.status,
          total               = excluded.total,
          comment             = excluded.comment,
          payment_status      = excluded.payment_status,
          provider_payment_id = excluded.provider_payment_id,
          paid_at             = excluded.paid_at
      ''',
        [
          order.id,
          order.orderNumber,
          order.createdAt.toIso8601String(),
          order.customerFirstName,
          order.customerLastName,
          order.status.value,
          order.total,
          order.comment,
          order.paymentMethod.value,
          order.paymentStatus.value,
          order.providerPaymentId,
          order.paidAt?.toIso8601String(),
        ],
      );

      // Replace items (delete + insert) only for new orders
      final existingItems = _db.select(
        'SELECT COUNT(*) AS cnt FROM order_items WHERE order_id = ?',
        [order.id],
      );
      if ((existingItems.first['cnt'] as int) == 0) {
        for (final item in order.items) {
          _db.execute(
            'INSERT INTO order_items (id, order_id, product_id, name_snapshot, price_snapshot, qty) '
            'VALUES (?, ?, ?, ?, ?, ?)',
            [
              item.id,
              order.id,
              item.productId,
              item.nameSnapshot,
              item.priceSnapshot,
              item.qty,
            ],
          );
          for (final mod in item.modifiers) {
            _db.execute(
              'INSERT INTO order_item_modifiers (order_item_id, name_snapshot, price_delta_snapshot) '
              'VALUES (?, ?, ?)',
              [item.id, mod.nameSnapshot, mod.priceDeltaSnapshot],
            );
          }
        }
      }

      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Payments  (Map-like wrappers)
  // ---------------------------------------------------------------------------

  late final PaymentsMap paymentsById = PaymentsMap._(_db);
  late final PaymentIdByOrderIdMap paymentIdByOrderId = PaymentIdByOrderIdMap._(
    _db,
  );

  void savePayment(PaymentSession payment) {
    _db.execute(
      '''
      INSERT INTO payments (id, order_id, amount, status, checkout_url, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        status     = excluded.status,
        updated_at = excluded.updated_at
    ''',
      [
        payment.id,
        payment.orderId,
        payment.amount,
        payment.status.value,
        payment.checkoutUrl,
        payment.createdAt.toIso8601String(),
        payment.updatedAt.toIso8601String(),
      ],
    );
  }

  void dispose() {
    _db.dispose();
  }
}

// =============================================================================
// Map-like wrappers
// =============================================================================

class ProductsMap {
  ProductsMap._(this._db);
  final Database _db;

  Product? operator [](String id) {
    final rows = _db.select('SELECT * FROM products WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _rowToProduct(rows.first);
  }

  void operator []=(String id, Product p) {
    _db.execute('BEGIN');
    try {
      _db.execute(
        '''
        INSERT INTO products (id, category_id, name, description, price, image_url, is_available)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          category_id  = excluded.category_id,
          name         = excluded.name,
          description  = excluded.description,
          price        = excluded.price,
          image_url    = excluded.image_url,
          is_available = excluded.is_available
      ''',
        [
          p.id,
          p.categoryId,
          p.name,
          p.description,
          p.price,
          p.imageUrl,
          p.isAvailable ? 1 : 0,
        ],
      );

      // Replace modifier groups + items
      // First collect existing group ids to delete their items
      final oldGroups = _db.select(
        'SELECT id FROM modifier_groups WHERE product_id = ?',
        [p.id],
      );
      for (final row in oldGroups) {
        _db.execute('DELETE FROM modifier_items WHERE group_id = ?', [
          row['id'],
        ]);
      }
      _db.execute('DELETE FROM modifier_groups WHERE product_id = ?', [p.id]);

      for (final g in p.modifierGroups) {
        _db.execute(
          'INSERT INTO modifier_groups (id, product_id, name, min_val, max_val) VALUES (?, ?, ?, ?, ?)',
          [g.id, p.id, g.name, g.min, g.max],
        );
        for (final item in g.items) {
          _db.execute(
            'INSERT INTO modifier_items (id, group_id, name, price_delta) VALUES (?, ?, ?, ?)',
            [item.id, g.id, item.name, item.priceDelta],
          );
        }
      }

      _db.execute('COMMIT');
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  Iterable<Product> get values {
    final rows = _db.select('SELECT * FROM products ORDER BY name');
    return rows.map(_rowToProduct);
  }

  Product _rowToProduct(Row row) {
    final productId = row['id'] as String;
    final groups = _db.select(
      'SELECT * FROM modifier_groups WHERE product_id = ? ORDER BY rowid',
      [productId],
    );

    final modifierGroups = groups.map((g) {
      final groupId = g['id'] as String;
      final items = _db.select(
        'SELECT * FROM modifier_items WHERE group_id = ? ORDER BY rowid',
        [groupId],
      );
      return ModifierGroup(
        id: groupId,
        name: g['name'] as String,
        min: g['min_val'] as int,
        max: g['max_val'] as int,
        items: items
            .map(
              (i) => ModifierItem(
                id: i['id'] as String,
                name: i['name'] as String,
                priceDelta: (i['price_delta'] as num).toDouble(),
              ),
            )
            .toList(),
      );
    }).toList();

    return Product(
      id: productId,
      categoryId: row['category_id'] as String,
      name: row['name'] as String,
      description: row['description'] as String,
      price: (row['price'] as num).toDouble(),
      imageUrl: row['image_url'] as String,
      isAvailable: (row['is_available'] as int) == 1,
      modifierGroups: modifierGroups,
    );
  }
}

class StaffMap {
  StaffMap._(this._db);
  final Database _db;

  StaffUser? operator [](String pin) {
    final rows = _db.select('SELECT * FROM staff WHERE pin = ?', [pin]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return StaffUser(
      id: r['id'] as String,
      name: r['name'] as String,
      role: r['role'] as String,
    );
  }
}

class OrdersMap {
  OrdersMap._(this._db);
  final Database _db;

  CafeOrder? operator [](String id) {
    final rows = _db.select('SELECT * FROM orders WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _rowToOrder(rows.first);
  }

  Iterable<CafeOrder> get values {
    final rows = _db.select('SELECT * FROM orders');
    return rows.map(_rowToOrder);
  }

  CafeOrder _rowToOrder(Row row) {
    final orderId = row['id'] as String;

    final itemRows = _db.select(
      'SELECT * FROM order_items WHERE order_id = ?',
      [orderId],
    );

    final items = itemRows.map((ir) {
      final itemId = ir['id'] as String;
      final modRows = _db.select(
        'SELECT * FROM order_item_modifiers WHERE order_item_id = ?',
        [itemId],
      );
      final modifiers = modRows
          .map(
            (mr) => OrderItemModifier(
              nameSnapshot: mr['name_snapshot'] as String,
              priceDeltaSnapshot: (mr['price_delta_snapshot'] as num)
                  .toDouble(),
            ),
          )
          .toList();

      return OrderItem(
        id: itemId,
        productId: ir['product_id'] as String,
        nameSnapshot: ir['name_snapshot'] as String,
        priceSnapshot: (ir['price_snapshot'] as num).toDouble(),
        qty: ir['qty'] as int,
        modifiers: modifiers,
      );
    }).toList();

    final paidAtRaw = row['paid_at'] as String?;

    return CafeOrder(
      id: orderId,
      orderNumber: row['order_number'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      customerFirstName: row['customer_first_name'] as String? ?? '',
      customerLastName: row['customer_last_name'] as String? ?? '',
      status:
          OrderStatusX.fromValue(row['status'] as String) ??
          OrderStatus.created,
      total: (row['total'] as num).toDouble(),
      comment: row['comment'] as String?,
      paymentMethod:
          PaymentMethodX.fromValue(row['payment_method'] as String) ??
          PaymentMethod.payOnPickup,
      paymentStatus: _paymentStatusFromValue(row['payment_status'] as String),
      providerPaymentId: row['provider_payment_id'] as String?,
      paidAt: paidAtRaw != null ? DateTime.parse(paidAtRaw) : null,
      items: items,
    );
  }

  PaymentStatus _paymentStatusFromValue(String value) {
    for (final s in PaymentStatus.values) {
      if (s.value == value) return s;
    }
    return PaymentStatus.unpaid;
  }
}

class PaymentsMap {
  PaymentsMap._(this._db);
  final Database _db;

  PaymentSession? operator [](String id) {
    final rows = _db.select('SELECT * FROM payments WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _rowToPayment(rows.first);
  }

  PaymentSession _rowToPayment(Row row) {
    return PaymentSession(
      id: row['id'] as String,
      orderId: row['order_id'] as String,
      amount: (row['amount'] as num).toDouble(),
      status: _sessionStatusFromValue(row['status'] as String),
      checkoutUrl: row['checkout_url'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  PaymentSessionStatus _sessionStatusFromValue(String value) {
    for (final s in PaymentSessionStatus.values) {
      if (s.value == value) return s;
    }
    return PaymentSessionStatus.created;
  }
}

class PaymentIdByOrderIdMap {
  PaymentIdByOrderIdMap._(this._db);
  final Database _db;

  String? operator [](String orderId) {
    final rows = _db.select('SELECT id FROM payments WHERE order_id = ?', [
      orderId,
    ]);
    if (rows.isEmpty) return null;
    return rows.first['id'] as String;
  }
}
