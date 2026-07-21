abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Caixa físico PDV-01 (cx_cash_registers.id) — valor do Swagger.
  static const cashRegisterId = String.fromEnvironment(
    'CASH_REGISTER_ID',
    defaultValue: 'd636bba3-0bdb-35e0-90f9-713b04d19ce8',
  );

  /// Depósito default. ⚠️ NÃO reconfirmado neste lote — confirme com
  /// `SELECT id FROM stk_warehouses`. A venda usa isto; se errado → 422.
  static const defaultWarehouseId = String.fromEnvironment(
    'DEFAULT_WAREHOUSE_ID',
    defaultValue: '4ef956c0-4b83-3764-aad8-27527406da60',
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
