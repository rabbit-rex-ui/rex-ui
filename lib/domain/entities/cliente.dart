import 'package:equatable/equatable.dart';

import 'package:rabbit_pdv/domain/enums/cliente_tipo.dart';

/// Cliente do atendimento. Imutável.
///
/// Para anônimo use [Cliente.anonimo].
class Cliente extends Equatable {
  final ClienteTipo tipo;

  /// Apenas se [tipo] == [ClienteTipo.cadastrado].
  final String? id;

  /// CPF/CNPJ formatado (`123.456.789-00`). Null se anônimo.
  final String? doc;

  /// Nome a mostrar. Para anônimo é `"Sem identificação"`.
  final String nome;

  /// Cliente participa do programa de fidelidade.
  final bool fidelidade;

  /// Cliente tem crediário ativo (pode estar bloqueado por inadimplência).
  final bool crediario;

  /// Crediário bloqueado por inadimplência. UI usa para desabilitar
  /// o método "crediário" no modal de pagamento.
  final bool crediarioBloqueado;

  const Cliente({
    required this.tipo,
    this.id,
    this.doc,
    required this.nome,
    this.fidelidade = false,
    this.crediario = false,
    this.crediarioBloqueado = false,
  });

  /// Cliente anônimo padrão de novo atendimento.
  static const Cliente anonimo = Cliente(
    tipo: ClienteTipo.anonimo,
    nome: 'Sem identificação',
  );

  Cliente copyWith({
    ClienteTipo? tipo,
    String? id,
    String? doc,
    String? nome,
    bool? fidelidade,
    bool? crediario,
    bool? crediarioBloqueado,
  }) {
    return Cliente(
      tipo: tipo ?? this.tipo,
      id: id ?? this.id,
      doc: doc ?? this.doc,
      nome: nome ?? this.nome,
      fidelidade: fidelidade ?? this.fidelidade,
      crediario: crediario ?? this.crediario,
      crediarioBloqueado: crediarioBloqueado ?? this.crediarioBloqueado,
    );
  }

  @override
  List<Object?> get props => [tipo, id, doc, nome, fidelidade, crediario, crediarioBloqueado];
}
