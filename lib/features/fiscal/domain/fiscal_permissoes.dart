/// Átomos de permissão das notas fiscais (claim `permissions` do JWT, guia
/// fiscal §6). A UI só esconde o que o operador não pode fazer — o backend
/// responde 403 de qualquer forma.
///
/// | Papel      | ver/imprimir | emitir/consultar | cancelar |
/// |------------|:------------:|:----------------:|:--------:|
/// | CASHIER    |      ✓       |        ✓         |    —     |
/// | SUPERVISOR |      ✓       |        ✓         |    ✓     |
/// | MANAGER    |      ✓       |        ✓         |    ✓     |
/// | OWNER      |      ✓       |        —         |    ✓     |
///
/// `fis.invoice.download_xml` não aparece aqui de propósito: XML, PDF e HTML
/// das notas ficam na retaguarda, não no PDV (respostas do backend v1, §9).
abstract final class FiscalPermissoes {
  static const ver = 'fis.invoice.view';
  static const emitir = 'fis.invoice.issue'; // também "Consultar SEFAZ"
  static const cancelar = 'fis.invoice.cancel';
}
