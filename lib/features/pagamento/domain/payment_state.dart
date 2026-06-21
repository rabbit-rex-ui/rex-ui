import 'package:rabbit_pdv/features/pagamento/domain/payment_slice.dart';

/// Snapshot imutável da configuração de pagamento de um atendimento.
/// É o que o [PaymentSessionStore] guarda entre aberturas do modal.
class PaymentState {
  final List<PaymentSlice> slices;
  final Map<int, String> assignment; // itemId → sliceId
  final String activeSliceId;

  const PaymentState({
    required this.slices,
    required this.assignment,
    required this.activeSliceId,
  });
}
