import '../models/models.dart';

class AppStore {
  AppStore._({
    required this.categories,
    required this.products,
    required this.staffByPin,
  });

  factory AppStore.seeded() {
    final categories = <Category>[
      const Category(id: 'cat_donuts', name: 'Пончики', sort: 1),
      const Category(id: 'cat_pancakes', name: 'Блины', sort: 2),
      const Category(id: 'cat_coffee', name: 'Кофе', sort: 3),
    ];

    final products = <String, Product>{
      'donut_classic': Product(
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
              ModifierItem(id: 'glaze_sugar', name: 'Сахарная', priceDelta: 0),
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
      'donut_berry': Product(
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
              ModifierItem(id: 'top_none', name: 'Без посыпки', priceDelta: 0),
              ModifierItem(id: 'top_nuts', name: 'Орехи', priceDelta: 15),
              ModifierItem(id: 'top_coconut', name: 'Кокос', priceDelta: 10),
            ],
          ),
        ],
      ),
      'pancake_ham': Product(
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
              ModifierItem(id: 'fill_cottage', name: 'Творог', priceDelta: 20),
            ],
          ),
        ],
      ),
      'coffee_cappuccino': Product(
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
              ModifierItem(id: 'syrup_none', name: 'Без сиропа', priceDelta: 0),
              ModifierItem(id: 'syrup_vanilla', name: 'Ваниль', priceDelta: 20),
              ModifierItem(
                id: 'syrup_hazelnut',
                name: 'Фундук',
                priceDelta: 20,
              ),
            ],
          ),
        ],
      ),
    };

    final staff = {
      '1111': const StaffUser(
        id: 'stf_cashier',
        name: 'Cashier',
        role: 'cashier',
      ),
      '2222': const StaffUser(
        id: 'stf_barista',
        name: 'Barista',
        role: 'barista',
      ),
      '9999': const StaffUser(id: 'stf_admin', name: 'Admin', role: 'admin'),
    };

    return AppStore._(
      categories: categories,
      products: products,
      staffByPin: staff,
    );
  }

  final List<Category> categories;
  final Map<String, Product> products;
  final Map<String, StaffUser> staffByPin;

  final Map<String, CafeOrder> ordersById = {};
  final Map<String, String> orderIdByOrderNumber = {};
  final Map<String, PaymentSession> paymentsById = {};
  final Map<String, String> paymentIdByOrderId = {};

  int _orderCounter = 100;

  String nextOrderNumber() {
    _orderCounter += 1;
    return 'A-$_orderCounter';
  }

  void saveOrder(CafeOrder order) {
    ordersById[order.id] = order;
    orderIdByOrderNumber[order.orderNumber] = order.id;
  }

  CafeOrder? orderByNumber(String orderNumber) {
    final orderId = orderIdByOrderNumber[orderNumber];
    if (orderId == null) {
      return null;
    }
    return ordersById[orderId];
  }

  void savePayment(PaymentSession payment) {
    paymentsById[payment.id] = payment;
    paymentIdByOrderId[payment.orderId] = payment.id;
  }
}
