import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'package:rabbit_pdv/core/failures/failure.dart';
import 'package:rabbit_pdv/core/result/result.dart';

/// Envia bytes prontos (ESC/POS) a uma fila de impressão, sem driver gráfico
/// nem diálogo — "RAW" (guia fiscal v2.3 §9.3, opção A).
abstract interface class ImpressoraRaw {
  /// Nomes das impressoras instaladas (locais e de rede) no terminal.
  Future<Result<List<String>, Failure>> listar();

  /// Envia [bytes] para a fila [impressora]. [documento] é o nome que aparece
  /// na fila do Windows.
  Future<Result<void, Failure>> enviar(
    String impressora,
    Uint8List bytes, {
    required String documento,
  });
}

/// Implementação Windows: Print Spooler (`winspool.drv`) via `dart:ffi`.
///
/// `OpenPrinterW` → `StartDocPrinterW` (tipo `RAW`) → `StartPagePrinter` →
/// `WritePrinter` → `EndPagePrinter` → `EndDocPrinter` → `ClosePrinter`.
/// Roda num isolate: um spooler lento não trava a tela.
class ImpressoraRawWindows implements ImpressoraRaw {
  static const _dispositivo = 'impressora';

  @override
  Future<Result<List<String>, Failure>> listar() async {
    if (!Platform.isWindows) return Err(_somenteWindows());
    try {
      return Ok(await Isolate.run(_listarImpressoras));
    } on Object catch (e) {
      return Err(_falha(e));
    }
  }

  @override
  Future<Result<void, Failure>> enviar(
    String impressora,
    Uint8List bytes, {
    required String documento,
  }) async {
    if (!Platform.isWindows) return Err(_somenteWindows());
    try {
      await Isolate.run(() => _enviarRaw(impressora, documento, bytes));
      return const Ok(null);
    } on Object catch (e) {
      return Err(_falha(e));
    }
  }

  /// Erro do spooler (mensagem pronta) ou qualquer outro vindo do isolate
  /// (inclusive `RemoteError`) — sempre vira falha tipada, nunca exceção solta.
  static Failure _falha(Object e) => HardwareFailure(
    e is _ErroSpooler ? e.mensagem : 'Falha ao acessar a impressora: $e',
    device: _dispositivo,
    cause: e,
  );

  static Failure _somenteWindows() => const HardwareFailure(
    'A impressão térmica só está disponível no Windows.',
    device: _dispositivo,
  );
}

// ─────────────────────── winspool.drv (Win32) ───────────────────────

/// `DOC_INFO_1W`.
final class _DocInfo1 extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDatatype;
}

/// `PRINTER_INFO_4W` (nível 4: só nome — rápido, não consulta a impressora).
final class _PrinterInfo4 extends Struct {
  external Pointer<Utf16> pPrinterName;
  external Pointer<Utf16> pServerName;
  @Uint32()
  external int attributes;
}

typedef _OpenPrinterNativo =
    Int32 Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>);
typedef _OpenPrinter = int Function(Pointer<Utf16>, Pointer<IntPtr>, Pointer<Void>);

typedef _StartDocNativo = Uint32 Function(IntPtr, Uint32, Pointer<_DocInfo1>);
typedef _StartDoc = int Function(int, int, Pointer<_DocInfo1>);

typedef _WritePrinterNativo =
    Int32 Function(IntPtr, Pointer<Uint8>, Uint32, Pointer<Uint32>);
typedef _WritePrinter = int Function(int, Pointer<Uint8>, int, Pointer<Uint32>);

/// StartPagePrinter, EndPagePrinter, EndDocPrinter, ClosePrinter.
typedef _ComHandleNativo = Int32 Function(IntPtr);
typedef _ComHandle = int Function(int);

typedef _EnumPrintersNativo =
    Int32 Function(
      Uint32,
      Pointer<Utf16>,
      Uint32,
      Pointer<Uint8>,
      Uint32,
      Pointer<Uint32>,
      Pointer<Uint32>,
    );
typedef _EnumPrinters =
    int Function(
      int,
      Pointer<Utf16>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Uint32>,
      Pointer<Uint32>,
    );

const _printerEnumLocal = 0x00000002;
const _printerEnumConnections = 0x00000004;

void _enviarRaw(String impressora, String documento, Uint8List bytes) {
  final winspool = DynamicLibrary.open('winspool.drv');
  final openPrinter = winspool
      .lookupFunction<_OpenPrinterNativo, _OpenPrinter>('OpenPrinterW');
  final startDoc = winspool
      .lookupFunction<_StartDocNativo, _StartDoc>('StartDocPrinterW');
  final startPage = winspool
      .lookupFunction<_ComHandleNativo, _ComHandle>('StartPagePrinter');
  final writePrinter = winspool
      .lookupFunction<_WritePrinterNativo, _WritePrinter>('WritePrinter');
  final endPage = winspool
      .lookupFunction<_ComHandleNativo, _ComHandle>('EndPagePrinter');
  final endDoc = winspool
      .lookupFunction<_ComHandleNativo, _ComHandle>('EndDocPrinter');
  final closePrinter = winspool
      .lookupFunction<_ComHandleNativo, _ComHandle>('ClosePrinter');

  using((arena) {
    final handle = arena<IntPtr>();
    final nome = impressora.toNativeUtf16(allocator: arena);
    if (openPrinter(nome, handle, nullptr) == 0) {
      throw _ErroSpooler('Impressora "$impressora" não encontrada.');
    }
    final h = handle.value;
    try {
      final doc = arena<_DocInfo1>();
      doc.ref
        ..pDocName = documento.toNativeUtf16(allocator: arena)
        ..pOutputFile = nullptr
        ..pDatatype = 'RAW'.toNativeUtf16(allocator: arena);
      if (startDoc(h, 1, doc) == 0) {
        throw _ErroSpooler(
          'A impressora "$impressora" recusou o documento. Ela está '
          'pausada ou offline?',
        );
      }
      try {
        startPage(h);
        final buffer = arena<Uint8>(bytes.length);
        buffer.asTypedList(bytes.length).setAll(0, bytes);
        final escritos = arena<Uint32>();
        final ok = writePrinter(h, buffer, bytes.length, escritos);
        if (ok == 0 || escritos.value != bytes.length) {
          throw _ErroSpooler(
            'Falha ao enviar para a impressora "$impressora".',
          );
        }
        endPage(h);
      } finally {
        endDoc(h);
      }
    } finally {
      closePrinter(h);
    }
  });
}

List<String> _listarImpressoras() {
  final winspool = DynamicLibrary.open('winspool.drv');
  final enumPrinters = winspool
      .lookupFunction<_EnumPrintersNativo, _EnumPrinters>('EnumPrintersW');
  const flags = _printerEnumLocal | _printerEnumConnections;

  return using((arena) {
    final necessario = arena<Uint32>();
    final quantidade = arena<Uint32>();
    // 1ª chamada só descobre o tamanho do buffer (falha de propósito).
    enumPrinters(flags, nullptr, 4, nullptr, 0, necessario, quantidade);
    if (necessario.value == 0) return const <String>[];

    final buffer = arena<Uint8>(necessario.value);
    final ok = enumPrinters(
      flags,
      nullptr,
      4,
      buffer,
      necessario.value,
      necessario,
      quantidade,
    );
    if (ok == 0) {
      throw const _ErroSpooler('Não foi possível listar as impressoras.');
    }
    final infos = buffer.cast<_PrinterInfo4>();
    return [
      for (var i = 0; i < quantidade.value; i++)
        infos[i].pPrinterName.toDartString(),
    ]..sort();
  });
}

class _ErroSpooler implements Exception {
  const _ErroSpooler(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}
