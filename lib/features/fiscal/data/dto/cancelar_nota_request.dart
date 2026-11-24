/// Corpo de `POST /fis/notas/{id}/cancelar` (guia fiscal §6.2).
///
/// A [justificativa] vai para a SEFAZ (15–255 caracteres — ver
/// `JustificativaCancelamento`).
class CancelarNotaRequest {
  const CancelarNotaRequest({required this.justificativa});

  final String justificativa;

  Map<String, dynamic> toJson() => {'justificativa': justificativa};
}
