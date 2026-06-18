abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const tenantId = String.fromEnvironment(
    'TENANT_ID',
    defaultValue: '019ddaa7-0b5c-7fbd-a536-0e27a602e8ed',
  );
  static const terminalId = String.fromEnvironment(
    'TERMINAL_ID',
    defaultValue: 'TERM-001',
  );

  /// Caixa físico PDV-01 (cx_cash_registers.id) — valor do Swagger.
  static const cashRegisterId = String.fromEnvironment(
    'CASH_REGISTER_ID',
    defaultValue: 'b54a5792-727a-32c1-8716-35cb7f1649d6',
  );

  /// Depósito default. ⚠️ NÃO reconfirmado neste lote — confirme com
  /// `SELECT id FROM stk_warehouses`. A venda usa isto; se errado → 422.
  static const defaultWarehouseId = String.fromEnvironment(
    'DEFAULT_WAREHOUSE_ID',
    defaultValue: '018fbdc0-0000-7000-8000-000000000010',
  );

  // Credenciais de dev (até existir tela de login). Em produção, nunca commitar.
  static const devLoginCode = String.fromEnvironment(
    'DEV_LOGIN_CODE',
    defaultValue: '10000003',
  );
  static const devPassword = String.fromEnvironment(
    'DEV_PASSWORD',
    defaultValue: 'Dev@12345',
  );

  static const openingFloat = 125.40;
}
