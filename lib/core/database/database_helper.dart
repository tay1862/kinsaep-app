import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kinsaep_pos/core/network/cloud_state.dart';
import 'package:kinsaep_pos/core/utils/pin_security.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kinsaep_pos.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, fileName);
    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE sales ADD COLUMN ticketName TEXT');
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE items ADD COLUMN modifiers TEXT DEFAULT '[]'",
      );
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE shifts (
          id TEXT PRIMARY KEY,
          openedAt TEXT NOT NULL,
          closedAt TEXT,
          startingCash REAL NOT NULL DEFAULT 0,
          cashAdded REAL NOT NULL DEFAULT 0,
          cashRemoved REAL NOT NULL DEFAULT 0,
          expectedCash REAL,
          actualCash REAL,
          difference REAL,
          status TEXT NOT NULL DEFAULT 'open',
          syncStatus TEXT NOT NULL DEFAULT 'PENDING'
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE store_settings ADD COLUMN receiptHeader TEXT',
      );
      await db.execute(
        'ALTER TABLE store_settings ADD COLUMN receiptFooter TEXT',
      );
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE staff (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          pin TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'CASHIER',
          isActive INTEGER NOT NULL DEFAULT 1,
          createdAt TEXT,
          updatedAt TEXT
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE store_settings ADD COLUMN serverUrl TEXT');
      await db.execute(
        'ALTER TABLE store_settings ADD COLUMN syncEnabled INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        "ALTER TABLE store_settings ADD COLUMN cloudMode TEXT NOT NULL DEFAULT '${CloudMode.offlineOnly}'",
      );
      await db.execute(
        "ALTER TABLE store_settings ADD COLUMN subscriptionStatus TEXT NOT NULL DEFAULT '${CloudSubscriptionStatus.none}'",
      );
      await db.execute(
        'ALTER TABLE store_settings ADD COLUMN remoteStoreId TEXT',
      );
      await db.execute('ALTER TABLE store_settings ADD COLUMN lastSyncAt TEXT');
      await _migrateLegacyPins(db);
    }
    if (oldVersion < 8) {
      await db.execute("ALTER TABLE items ADD COLUMN kitchenStationId TEXT");
      await db.execute('ALTER TABLE items ADD COLUMN imageUrl TEXT');
      await db.execute("ALTER TABLE store_settings ADD COLUMN deviceId TEXT");
      await db.execute(
        "ALTER TABLE store_settings ADD COLUMN deviceName TEXT NOT NULL DEFAULT 'This Device'",
      );
      await db.execute(
        "ALTER TABLE store_settings ADD COLUMN deviceType TEXT NOT NULL DEFAULT 'POS'",
      );
      await db.execute(
        "ALTER TABLE store_settings ADD COLUMN scannerMode TEXT NOT NULL DEFAULT 'AUTO'",
      );
      await db.execute(
        "ALTER TABLE store_settings ADD COLUMN syncProfile TEXT NOT NULL DEFAULT 'LIGHT'",
      );
      await db.execute('ALTER TABLE store_settings ADD COLUMN printerMac TEXT');
      await db.execute(
        'ALTER TABLE store_settings ADD COLUMN printerName TEXT',
      );
      await db.execute(
        "ALTER TABLE store_settings ADD COLUMN currentSyncStatus TEXT NOT NULL DEFAULT 'IDLE'",
      );
      await db.execute(
        'ALTER TABLE store_settings ADD COLUMN lastSyncProgress INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE store_settings ADD COLUMN lastSyncError TEXT',
      );
      await db.execute(
        "ALTER TABLE staff ADD COLUMN updatedAt TEXT DEFAULT ''",
      );
      await db.execute('''
        CREATE TABLE devices (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'POS',
          platform TEXT NOT NULL DEFAULT 'ANDROID',
          scannerMode TEXT NOT NULL DEFAULT 'AUTO',
          syncProfile TEXT NOT NULL DEFAULT 'OFF',
          status TEXT NOT NULL DEFAULT 'OFFLINE',
          isActive INTEGER NOT NULL DEFAULT 1,
          lastSeenAt TEXT,
          createdAt TEXT,
          updatedAt TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE sync_jobs (
          id TEXT PRIMARY KEY,
          direction TEXT NOT NULL,
          status TEXT NOT NULL,
          progress INTEGER NOT NULL DEFAULT 0,
          scopes TEXT,
          error TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE tombstones (
          id TEXT PRIMARY KEY,
          entityType TEXT NOT NULL,
          entityId TEXT NOT NULL,
          payload TEXT,
          deletedAt TEXT NOT NULL,
          syncStatus TEXT NOT NULL DEFAULT 'PENDING'
        )
      ''');
      await db.execute('''
        CREATE TABLE media_assets (
          id TEXT PRIMARY KEY,
          itemId TEXT,
          fileName TEXT NOT NULL,
          mimeType TEXT NOT NULL,
          imagePath TEXT,
          thumbnailBase64 TEXT,
          remoteUrl TEXT,
          syncStatus TEXT NOT NULL DEFAULT 'PENDING',
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE kitchen_stations (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1,
          createdAt TEXT,
          updatedAt TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE kitchen_screens (
          id TEXT PRIMARY KEY,
          stationId TEXT NOT NULL,
          deviceId TEXT NOT NULL,
          label TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1,
          createdAt TEXT,
          updatedAt TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE kitchen_tickets (
          id TEXT PRIMARY KEY,
          saleId TEXT,
          sourceDeviceId TEXT,
          status TEXT NOT NULL DEFAULT 'NEW',
          note TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          syncStatus TEXT NOT NULL DEFAULT 'SYNCED'
        )
      ''');
      await db.execute('''
        CREATE TABLE kitchen_ticket_items (
          id TEXT PRIMARY KEY,
          ticketId TEXT NOT NULL,
          itemId TEXT,
          stationId TEXT,
          itemName TEXT NOT NULL,
          quantity REAL NOT NULL DEFAULT 1,
          status TEXT NOT NULL DEFAULT 'NEW',
          note TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE sales_summaries (
          id TEXT PRIMARY KEY,
          businessDay TEXT NOT NULL,
          totalOrders INTEGER NOT NULL DEFAULT 0,
          totalSales REAL NOT NULL DEFAULT 0,
          cashTotal REAL NOT NULL DEFAULT 0,
          otherTotal REAL NOT NULL DEFAULT 0,
          updatedAt TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // ─── Categories ───
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL DEFAULT 0xFF3B82F6,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'SYNCED'
      )
    ''');

    // ─── Items ───
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL DEFAULT 0,
        cost REAL NOT NULL DEFAULT 0,
        categoryId TEXT,
        barcode TEXT,
        sku TEXT,
        imagePath TEXT,
        imageUrl TEXT,
        kitchenStationId TEXT,
        trackStock INTEGER NOT NULL DEFAULT 0,
        stockQuantity REAL NOT NULL DEFAULT 0,
        lowStockThreshold REAL NOT NULL DEFAULT 5,
        isActive INTEGER NOT NULL DEFAULT 1,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        modifiers TEXT DEFAULT '[]',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'SYNCED',
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    // ─── Sales ───
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        receiptNumber TEXT NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0,
        discountAmount REAL NOT NULL DEFAULT 0,
        discountPercent REAL NOT NULL DEFAULT 0,
        taxAmount REAL NOT NULL DEFAULT 0,
        totalAmount REAL NOT NULL DEFAULT 0,
        amountPaid REAL NOT NULL DEFAULT 0,
        changeAmount REAL NOT NULL DEFAULT 0,
        paymentMethod TEXT NOT NULL DEFAULT 'cash',
        status TEXT NOT NULL DEFAULT 'completed',
        note TEXT,
        ticketName TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'PENDING'
      )
    ''');

    // ─── Sale Items ───
    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        saleId TEXT NOT NULL,
        itemId TEXT NOT NULL,
        itemName TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unitPrice REAL NOT NULL DEFAULT 0,
        totalPrice REAL NOT NULL DEFAULT 0,
        note TEXT,
        FOREIGN KEY (saleId) REFERENCES sales(id) ON DELETE CASCADE,
        FOREIGN KEY (itemId) REFERENCES items(id)
      )
    ''');

    // ─── Store Settings ───
    await db.execute('''
      CREATE TABLE store_settings (
        id INTEGER PRIMARY KEY DEFAULT 1,
        storeName TEXT NOT NULL DEFAULT 'My Store',
        storeAddress TEXT,
        storePhone TEXT,
        businessType TEXT NOT NULL DEFAULT 'retail',
        currency TEXT NOT NULL DEFAULT 'LAK',
        locale TEXT NOT NULL DEFAULT 'lo',
        taxEnabled INTEGER NOT NULL DEFAULT 0,
        taxRate REAL NOT NULL DEFAULT 0,
        receiptCounter INTEGER NOT NULL DEFAULT 0,
        isSetupComplete INTEGER NOT NULL DEFAULT 0,
        receiptHeader TEXT,
        receiptFooter TEXT,
        serverUrl TEXT,
        syncEnabled INTEGER NOT NULL DEFAULT 0,
        cloudMode TEXT NOT NULL DEFAULT 'OFFLINE_ONLY',
        subscriptionStatus TEXT NOT NULL DEFAULT 'NONE',
        remoteStoreId TEXT,
        lastSyncAt TEXT,
        deviceId TEXT,
        deviceName TEXT NOT NULL DEFAULT 'This Device',
        deviceType TEXT NOT NULL DEFAULT 'POS',
        scannerMode TEXT NOT NULL DEFAULT 'AUTO',
        syncProfile TEXT NOT NULL DEFAULT 'LIGHT',
        printerMac TEXT,
        printerName TEXT,
        currentSyncStatus TEXT NOT NULL DEFAULT 'IDLE',
        lastSyncProgress INTEGER NOT NULL DEFAULT 0,
        lastSyncError TEXT
      )
    ''');

    // Insert default settings
    await db.insert('store_settings', {
      'id': 1,
      'storeName': 'My Store',
      'businessType': 'retail',
      'currency': 'LAK',
      'locale': 'lo',
      'taxEnabled': 0,
      'taxRate': 0,
      'receiptCounter': 0,
      'isSetupComplete': 0,
      'syncEnabled': 0,
      'cloudMode': CloudMode.offlineOnly,
      'subscriptionStatus': CloudSubscriptionStatus.none,
      'deviceName': 'This Device',
      'deviceType': 'POS',
      'scannerMode': 'AUTO',
      'syncProfile': 'LIGHT',
      'currentSyncStatus': 'IDLE',
      'lastSyncProgress': 0,
    });

    // ─── Staff (RBAC & PINs) ───
    await db.execute('''
      CREATE TABLE staff (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        pin TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'CASHIER',
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE devices (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'POS',
        platform TEXT NOT NULL DEFAULT 'ANDROID',
        scannerMode TEXT NOT NULL DEFAULT 'AUTO',
        syncProfile TEXT NOT NULL DEFAULT 'OFF',
        status TEXT NOT NULL DEFAULT 'OFFLINE',
        isActive INTEGER NOT NULL DEFAULT 1,
        lastSeenAt TEXT,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_jobs (
        id TEXT PRIMARY KEY,
        direction TEXT NOT NULL,
        status TEXT NOT NULL,
        progress INTEGER NOT NULL DEFAULT 0,
        scopes TEXT,
        error TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tombstones (
        id TEXT PRIMARY KEY,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        payload TEXT,
        deletedAt TEXT NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'PENDING'
      )
    ''');

    await db.execute('''
      CREATE TABLE media_assets (
        id TEXT PRIMARY KEY,
        itemId TEXT,
        fileName TEXT NOT NULL,
        mimeType TEXT NOT NULL,
        imagePath TEXT,
        thumbnailBase64 TEXT,
        remoteUrl TEXT,
        syncStatus TEXT NOT NULL DEFAULT 'PENDING',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE kitchen_stations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE kitchen_screens (
        id TEXT PRIMARY KEY,
        stationId TEXT NOT NULL,
        deviceId TEXT NOT NULL,
        label TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT,
        updatedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE kitchen_tickets (
        id TEXT PRIMARY KEY,
        saleId TEXT,
        sourceDeviceId TEXT,
        status TEXT NOT NULL DEFAULT 'NEW',
        note TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'SYNCED'
      )
    ''');

    await db.execute('''
      CREATE TABLE kitchen_ticket_items (
        id TEXT PRIMARY KEY,
        ticketId TEXT NOT NULL,
        itemId TEXT,
        stationId TEXT,
        itemName TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'NEW',
        note TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales_summaries (
        id TEXT PRIMARY KEY,
        businessDay TEXT NOT NULL,
        totalOrders INTEGER NOT NULL DEFAULT 0,
        totalSales REAL NOT NULL DEFAULT 0,
        cashTotal REAL NOT NULL DEFAULT 0,
        otherTotal REAL NOT NULL DEFAULT 0,
        updatedAt TEXT NOT NULL
      )
    ''');

    // ─── Indexes ───
    await db.execute('CREATE INDEX idx_items_category ON items(categoryId)');
    await db.execute('CREATE INDEX idx_items_barcode ON items(barcode)');
    await db.execute('CREATE INDEX idx_sales_created ON sales(createdAt)');
    await db.execute('CREATE INDEX idx_sales_status ON sales(status)');
    await db.execute('CREATE INDEX idx_sale_items_sale ON sale_items(saleId)');

    // ─── Shifts ───
    await db.execute('''
      CREATE TABLE shifts (
        id TEXT PRIMARY KEY,
        openedAt TEXT NOT NULL,
        closedAt TEXT,
        startingCash REAL NOT NULL DEFAULT 0,
        cashAdded REAL NOT NULL DEFAULT 0,
        cashRemoved REAL NOT NULL DEFAULT 0,
        expectedCash REAL,
        actualCash REAL,
        difference REAL,
        status TEXT NOT NULL DEFAULT 'open',
        syncStatus TEXT NOT NULL DEFAULT 'PENDING'
      )
    ''');
  }

  Future<void> _migrateLegacyPins(Database db) async {
    final staffMembers = await db.query('staff', columns: ['id', 'pin']);

    for (final staff in staffMembers) {
      final id = staff['id'] as String?;
      final pin = staff['pin'] as String? ?? '';

      if (id == null || !PinSecurity.needsMigration(pin)) {
        continue;
      }

      await db.update(
        'staff',
        {'pin': PinSecurity.hashPin(pin)},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // ─── Category CRUD ───
  Future<int> insertCategory(Map<String, dynamic> row) async {
    final db = await database;
    final data = Map<String, dynamic>.from(row);
    data['syncStatus'] = 'PENDING';
    data['updatedAt'] = DateTime.now().toIso8601String();
    return await db.insert('categories', data);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('categories', orderBy: 'sortOrder ASC, name ASC');
  }

  Future<int> updateCategory(String id, Map<String, dynamic> row) async {
    final db = await database;
    final data = Map<String, dynamic>.from(row);
    data['syncStatus'] = 'PENDING';
    data['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update(
      'categories',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await database;
    await createTombstone('CATEGORY', id);
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Item CRUD ───
  Future<int> insertItem(Map<String, dynamic> row) async {
    final db = await database;
    final data = Map<String, dynamic>.from(row);
    data['syncStatus'] = 'PENDING';
    data['updatedAt'] = DateTime.now().toIso8601String();
    return await db.insert('items', data);
  }

  Future<List<Map<String, dynamic>>> getItems({String? categoryId}) async {
    final db = await database;
    if (categoryId != null) {
      return await db.query(
        'items',
        where: 'categoryId = ? AND isActive = 1',
        whereArgs: [categoryId],
        orderBy: 'sortOrder ASC, name ASC',
      );
    }
    return await db.query(
      'items',
      where: 'isActive = 1',
      orderBy: 'sortOrder ASC, name ASC',
    );
  }

  Future<List<Map<String, dynamic>>> searchItems(String query) async {
    final db = await database;
    return await db.query(
      'items',
      where: '(name LIKE ? OR barcode LIKE ? OR sku LIKE ?) AND isActive = 1',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
  }

  Future<Map<String, dynamic>?> findItemByCode(String code) async {
    final db = await database;
    final rows = await db.query(
      'items',
      where: '(barcode = ? OR sku = ?) AND isActive = 1',
      whereArgs: [code, code],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getItemsByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return [];
    }
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return db.query('items', where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<int> updateItem(String id, Map<String, dynamic> row) async {
    final db = await database;
    final data = Map<String, dynamic>.from(row);
    data['syncStatus'] = 'PENDING';
    data['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update('items', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateItemSilently(String id, Map<String, dynamic> row) async {
    final db = await database;
    final data = Map<String, dynamic>.from(row);
    if (!data.containsKey('updatedAt')) {
      data['updatedAt'] = DateTime.now().toIso8601String();
    }
    return await db.update('items', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteItem(String id) async {
    final db = await database;
    await createTombstone('ITEM', id);
    return await db.update(
      'items',
      {
        'isActive': 0,
        'syncStatus': 'PENDING',
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTicket(String saleId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sale_items', where: 'saleId = ?', whereArgs: [saleId]);
      await txn.delete(
        'sales',
        where: 'id = ? AND status = "open"',
        whereArgs: [saleId],
      );
    });
  }

  // ─── Shift CRUD ───
  Future<int> insertShift(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('shifts', row);
  }

  Future<Map<String, dynamic>?> getOpenShift() async {
    final db = await database;
    final res = await db.query('shifts', where: "status = 'open'", limit: 1);
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<int> updateShift(String id, Map<String, dynamic> row) async {
    final db = await database;
    final updates = Map<String, dynamic>.from(row);
    updates['syncStatus'] = 'PENDING';
    updates['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update('shifts', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getShifts({int limit = 50}) async {
    final db = await database;
    return await db.query('shifts', orderBy: 'openedAt DESC', limit: limit);
  }

  // ─── Sales & Tickets ───
  Future<void> insertSale(
    Map<String, dynamic> sale,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('sales', sale);
      for (final item in items) {
        await txn.insert('sale_items', item);
      }

      if (sale['status'] == 'completed') {
        // Update stock
        for (final item in items) {
          await txn.rawUpdate(
            'UPDATE items SET stockQuantity = stockQuantity - ? WHERE id = ? AND trackStock = 1',
            [item['quantity'], item['itemId']],
          );
        }
        // Increment receipt counter
        await txn.rawUpdate(
          'UPDATE store_settings SET receiptCounter = receiptCounter + 1 WHERE id = 1',
        );
      }
    });
  }

  Future<void> refundSale(String saleId) async {
    final db = await database;
    await db.transaction((txn) async {
      // Get sale items
      final items = await txn.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );

      // Update stock back
      for (final item in items) {
        await txn.rawUpdate(
          'UPDATE items SET stockQuantity = stockQuantity + ? WHERE id = ? AND trackStock = 1',
          [item['quantity'], item['itemId']],
        );
      }

      // Update sale status
      await txn.update(
        'sales',
        {
          'status': 'refunded',
          'syncStatus': 'PENDING',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );

      // We don't remove from shift records explicitly here, but we could add a cashRefunded column if building a full double-entry system.
    });
  }

  Future<void> updateTicketToSale(
    String saleId,
    Map<String, dynamic> saleUpdates,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await database;

    final updates = Map<String, dynamic>.from(saleUpdates);
    updates['syncStatus'] = 'PENDING';
    updates['updatedAt'] = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update('sales', updates, where: 'id = ?', whereArgs: [saleId]);

      // Delete old items and insert new ones
      await txn.delete('sale_items', where: 'saleId = ?', whereArgs: [saleId]);
      for (final item in items) {
        await txn.insert('sale_items', item);
      }

      if (saleUpdates['status'] == 'completed') {
        // Update stock
        for (final item in items) {
          await txn.rawUpdate(
            'UPDATE items SET stockQuantity = stockQuantity - ? WHERE id = ? AND trackStock = 1',
            [item['quantity'], item['itemId']],
          );
        }
        // Increment receipt counter
        await txn.rawUpdate(
          'UPDATE store_settings SET receiptCounter = receiptCounter + 1 WHERE id = 1',
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getOpenTickets() async {
    final db = await database;
    return await db.query(
      'sales',
      where: "status = 'open'",
      orderBy: 'createdAt DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getSales({String? date}) async {
    final db = await database;
    if (date != null) {
      return await db.query(
        'sales',
        where: "createdAt LIKE ? AND status IN ('completed', 'refunded')",
        whereArgs: ['$date%'],
        orderBy: 'createdAt DESC',
      );
    }
    return await db.query(
      'sales',
      where: "status IN ('completed', 'refunded')",
      orderBy: 'createdAt DESC',
      limit: 100,
    );
  }

  Future<List<Map<String, dynamic>>> getSaleItems(String saleId) async {
    final db = await database;
    return await db.query(
      'sale_items',
      where: 'saleId = ?',
      whereArgs: [saleId],
    );
  }

  Future<Map<String, dynamic>> getDailySummary(String date) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as totalOrders,
        COALESCE(SUM(totalAmount), 0) as totalSales,
        COALESCE(AVG(totalAmount), 0) as averageOrder,
        COALESCE(SUM(CASE WHEN paymentMethod = 'cash' THEN totalAmount ELSE 0 END), 0) as cashTotal,
        COALESCE(SUM(CASE WHEN paymentMethod != 'cash' THEN totalAmount ELSE 0 END), 0) as otherTotal
      FROM sales 
      WHERE createdAt LIKE ? AND status = 'completed'
    ''',
      ['$date%'],
    );
    return result.first;
  }

  Future<Map<String, dynamic>> getShiftSalesSummary(
    String openedAt,
    String? closedAt,
  ) async {
    final db = await database;
    String query = '''
      SELECT 
        COALESCE(SUM(CASE WHEN paymentMethod = 'cash' THEN totalAmount ELSE 0 END), 0) as cashSales,
        COALESCE(SUM(CASE WHEN paymentMethod != 'cash' THEN totalAmount ELSE 0 END), 0) as otherSales,
        COALESCE(SUM(totalAmount), 0) as totalSales
      FROM sales
      WHERE createdAt >= ? AND status = 'completed'
    ''';
    List<dynamic> args = [openedAt];
    if (closedAt != null) {
      query += ' AND createdAt <= ?';
      args.add(closedAt);
    }
    final result = await db.rawQuery(query, args);
    return result.first;
  }

  Future<List<Map<String, dynamic>>> getTopItems(String date) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT si.itemName, SUM(si.quantity) as totalQty, SUM(si.totalPrice) as totalRevenue
      FROM sale_items si
      JOIN sales s ON s.id = si.saleId
      WHERE s.createdAt LIKE ? AND s.status = 'completed'
      GROUP BY si.itemId
      ORDER BY totalQty DESC
      LIMIT 10
    ''',
      ['$date%'],
    );
  }

  // ─── Store Settings ───
  Future<Map<String, dynamic>> getSettings() async {
    final db = await database;
    final result = await db.query('store_settings', where: 'id = 1');
    return result.first;
  }

  Future<int> updateSettings(Map<String, dynamic> row) async {
    final db = await database;
    return await db.update('store_settings', row, where: 'id = 1');
  }

  Future<String> getOrCreateDeviceId() async {
    final settings = await getSettings();
    final existing = settings['deviceId'] as String?;
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final deviceId = 'device-${DateTime.now().millisecondsSinceEpoch}';
    await updateSettings({'deviceId': deviceId});
    return deviceId;
  }

  Future<void> createTombstone(
    String entityType,
    String entityId, {
    String? payload,
  }) async {
    final db = await database;
    await db.insert('tombstones', {
      'id':
          '${entityType.toLowerCase()}-$entityId-${DateTime.now().millisecondsSinceEpoch}',
      'entityType': entityType,
      'entityId': entityId,
      'payload': payload,
      'deletedAt': DateTime.now().toIso8601String(),
      'syncStatus': 'PENDING',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingTombstones() async {
    final db = await database;
    return db.query('tombstones', where: "syncStatus = 'PENDING'");
  }

  Future<void> markTombstonesSynced(List<Object?> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.update(
      'tombstones',
      {'syncStatus': 'SYNCED'},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<void> saveSyncJob(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert(
      'sync_jobs',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getSyncJobs({int limit = 20}) async {
    final db = await database;
    return db.query('sync_jobs', orderBy: 'createdAt DESC', limit: limit);
  }

  Future<void> upsertDevice(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert(
      'devices',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    final db = await database;
    return db.query('devices', orderBy: 'createdAt ASC');
  }

  Future<List<Map<String, dynamic>>> getActiveStaff() async {
    final db = await database;
    return db.query('staff', where: 'isActive = 1', orderBy: 'createdAt ASC');
  }

  Future<void> upsertStaffMember(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('staff', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStaffMember(String id, Map<String, dynamic> row) async {
    final db = await database;
    await db.update('staff', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveMediaAsset(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert(
      'media_assets',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingMediaAssets() async {
    final db = await database;
    return db.query('media_assets', where: "syncStatus = 'PENDING'");
  }

  Future<Map<String, dynamic>?> getMediaAssetForItem(String itemId) async {
    final db = await database;
    final rows = await db.query(
      'media_assets',
      where: 'itemId = ?',
      whereArgs: [itemId],
      orderBy: 'updatedAt DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> markMediaAssetSynced(String id, {String? remoteUrl}) async {
    final db = await database;
    await db.update(
      'media_assets',
      {
        'syncStatus': 'SYNCED',
        if (remoteUrl != null) 'remoteUrl': remoteUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> replaceKitchenSnapshot({
    required List<Map<String, dynamic>> stations,
    required List<Map<String, dynamic>> screens,
    required List<Map<String, dynamic>> tickets,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('kitchen_stations');
      await txn.delete('kitchen_screens');
      await txn.delete('kitchen_tickets');
      await txn.delete('kitchen_ticket_items');

      for (final station in stations) {
        await txn.insert('kitchen_stations', station);
      }
      for (final screen in screens) {
        await txn.insert('kitchen_screens', screen);
      }
      for (final ticket in tickets) {
        final ticketData = Map<String, dynamic>.from(ticket);
        final items = (ticketData.remove('items') as List<dynamic>? ?? []);
        await txn.insert('kitchen_tickets', ticketData);
        for (final item in items.cast<Map<String, dynamic>>()) {
          await txn.insert('kitchen_ticket_items', item);
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getKitchenStations() async {
    final db = await database;
    return db.query('kitchen_stations', orderBy: 'createdAt ASC');
  }

  Future<List<Map<String, dynamic>>> getKitchenScreens() async {
    final db = await database;
    return db.query('kitchen_screens', orderBy: 'createdAt ASC');
  }

  Future<void> saveKitchenStation(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert(
      'kitchen_stations',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveKitchenScreen(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert(
      'kitchen_screens',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> ensureDefaultKitchenStations() async {
    final db = await database;
    final existing = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM kitchen_stations'),
    );
    if ((existing ?? 0) > 0) {
      return;
    }

    final now = DateTime.now().toIso8601String();
    final defaults = [
      {'id': 'station-hot', 'name': 'Hot Kitchen', 'type': 'HOT'},
      {'id': 'station-cold', 'name': 'Cold Kitchen', 'type': 'COLD'},
      {'id': 'station-drink', 'name': 'Drink Bar', 'type': 'DRINK'},
    ];
    for (final station in defaults) {
      await db.insert('kitchen_stations', {
        ...station,
        'isActive': 1,
        'createdAt': now,
        'updatedAt': now,
      });
    }
  }

  Future<void> saveKitchenTicket(Map<String, dynamic> ticket) async {
    final db = await database;
    await db.insert(
      'kitchen_tickets',
      ticket,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceKitchenTicketItems(
    String ticketId,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'kitchen_ticket_items',
        where: 'ticketId = ?',
        whereArgs: [ticketId],
      );
      for (final item in items) {
        await txn.insert('kitchen_ticket_items', item);
      }
    });
  }

  Future<void> updateKitchenTicketStatus(String ticketId, String status) async {
    final db = await database;
    await db.update(
      'kitchen_tickets',
      {
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
        'syncStatus': 'PENDING',
      },
      where: 'id = ?',
      whereArgs: [ticketId],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingKitchenTickets() async {
    final db = await database;
    final tickets = await db.query(
      'kitchen_tickets',
      where: "syncStatus = 'PENDING'",
      orderBy: 'createdAt ASC',
    );
    final result = <Map<String, dynamic>>[];
    for (final ticket in tickets) {
      final items = await db.query(
        'kitchen_ticket_items',
        where: 'ticketId = ?',
        whereArgs: [ticket['id']],
      );
      result.add({...ticket, 'items': items});
    }
    return result;
  }

  Future<void> markKitchenTicketsSynced(List<Object?> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.update(
      'kitchen_tickets',
      {'syncStatus': 'SYNCED'},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<List<Map<String, dynamic>>> getKitchenTickets() async {
    final db = await database;
    final tickets = await db.query(
      'kitchen_tickets',
      orderBy: 'createdAt DESC',
    );

    final result = <Map<String, dynamic>>[];
    for (final ticket in tickets) {
      final items = await db.query(
        'kitchen_ticket_items',
        where: 'ticketId = ?',
        whereArgs: [ticket['id']],
      );
      result.add({...ticket, 'items': items});
    }
    return result;
  }

  Future<void> replaceSalesSummaries(
    List<Map<String, dynamic>> summaries,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final summary in summaries) {
        await txn.insert(
          'sales_summaries',
          summary,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSalesSummaries() async {
    final db = await database;
    return db.query('sales_summaries', orderBy: 'businessDay DESC');
  }

  Future<void> upsertCategoryRemote(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert(
      'categories',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertItemRemote(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('items', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertSaleRemote(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert('sales', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> replaceSaleItemsForSale(
    String saleId,
    List<Map<String, dynamic>> items,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sale_items', where: 'saleId = ?', whereArgs: [saleId]);
      for (final item in items) {
        await txn.insert('sale_items', item);
      }
    });
  }

  Future<void> upsertShiftRemote(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert(
      'shifts',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> applyTombstone(Map<String, dynamic> tombstone) async {
    final db = await database;
    await db.insert(
      'tombstones',
      tombstone,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    switch (tombstone['entityType']) {
      case 'CATEGORY':
        await db.delete(
          'categories',
          where: 'id = ?',
          whereArgs: [tombstone['entityId']],
        );
        break;
      case 'ITEM':
        await db.update(
          'items',
          {
            'isActive': 0,
            'updatedAt': DateTime.now().toIso8601String(),
            'syncStatus': 'SYNCED',
          },
          where: 'id = ?',
          whereArgs: [tombstone['entityId']],
        );
        break;
      case 'STAFF':
        await db.update(
          'staff',
          {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [tombstone['entityId']],
        );
        break;
      case 'DEVICE':
        await db.update(
          'devices',
          {
            'isActive': 0,
            'status': 'BLOCKED',
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [tombstone['entityId']],
        );
        break;
    }
  }

  Future<void> updateSyncState({
    required String status,
    required int progress,
    String? error,
    String? lastSyncAt,
  }) async {
    await updateSettings({
      'currentSyncStatus': status,
      'lastSyncProgress': progress,
      'lastSyncError': error,
      if (lastSyncAt != null) 'lastSyncAt': lastSyncAt,
    });
  }

  Future<int> getNextReceiptNumber() async {
    final settings = await getSettings();
    return (settings['receiptCounter'] as int) + 1;
  }

  Future<bool> hasLocalBusinessData() async {
    final db = await database;
    final results = await Future.wait([
      db.rawQuery('SELECT COUNT(*) as count FROM categories'),
      db.rawQuery('SELECT COUNT(*) as count FROM items'),
      db.rawQuery('SELECT COUNT(*) as count FROM sales'),
      db.rawQuery('SELECT COUNT(*) as count FROM shifts'),
    ]);

    return results.any((rows) => ((rows.first['count'] as int?) ?? 0) > 0);
  }
}
