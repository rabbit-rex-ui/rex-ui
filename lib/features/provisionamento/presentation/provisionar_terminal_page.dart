import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:rabbit_pdv/core/theme/app_colors.dart';
import 'package:rabbit_pdv/features/auth/presentation/login_controller.dart';
import 'package:rabbit_pdv/features/provisionamento/presentation/provisionar_terminal_controller.dart';

/// Parte 1 do provisionamento (back-office): login do gestor → registra a
/// estação confiável → resolve o caixa pelo code → emite o token → QR.
class ProvisionarTerminalPage extends StatefulWidget {
  const ProvisionarTerminalPage({super.key});

  @override
  State<ProvisionarTerminalPage> createState() =>
      _ProvisionarTerminalPageState();
}

class _ProvisionarTerminalPageState extends State<ProvisionarTerminalPage> {
  final _login = Modular.get<LoginController>();
  final _ctrl = Modular.get<ProvisionarTerminalController>();

  final _loginCodeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _codeCaixaCtrl = TextEditingController();
  final _rotuloCtrl = TextEditingController();

  @override
  void dispose() {
    _passCtrl.clear();
    _loginCodeCtrl.dispose();
    _passCtrl.dispose();
    _codeCaixaCtrl.dispose();
    _rotuloCtrl.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    final ok = await _login.submit(
      loginCode: _loginCodeCtrl.text,
      password: _passCtrl.text,
    );
    if (!mounted || !ok) return;
    _passCtrl.clear();
    // Rótulo da estação = nome amigável da máquina do gestor.
    await _ctrl.aposLogin(deviceLabelEstacao: 'Estação back-office');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'Provisionar terminal',
          style: TextStyle(color: colors.text, fontSize: 16),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: colors.text),
          onPressed: () => Modular.to.navigate('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AnimatedBuilder(
            animation: Listenable.merge([_login, _ctrl]),
            builder: (context, _) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: switch (_ctrl.etapa) {
                ProvisionarEtapa.login => _cardLogin(colors),
                ProvisionarEtapa.formulario => _cardForm(colors),
                ProvisionarEtapa.emitido => _cardToken(colors),
              },
            ),
          ),
        ),
      ),
    );
  }

  // ---- Etapa 1: login do gestor -------------------------------------------
  Widget _cardLogin(AppColors colors) {
    final loading = _login.loading || _ctrl.loading;
    return _card(colors, [
      _titulo(
        colors,
        LucideIcons.shieldCheck,
        'Acesso do gestor',
        'Autentique-se para provisionar este terminal.',
      ),
      const SizedBox(height: 20),
      _label('Código de login', colors),
      const SizedBox(height: 6),
      TextField(
        controller: _loginCodeCtrl,
        enabled: !loading,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => _login.clearError(),
        style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 15),
        decoration: _input(colors, hint: '10000002'),
      ),
      const SizedBox(height: 14),
      _label('Senha', colors),
      const SizedBox(height: 6),
      TextField(
        controller: _passCtrl,
        enabled: !loading,
        obscureText: _login.obscurePassword,
        onChanged: (_) => _login.clearError(),
        onSubmitted: (_) => loading ? null : _fazerLogin(),
        style: TextStyle(fontSize: 15, color: colors.text),
        decoration: _input(colors, hint: '••••••'),
      ),
      if ((_login.errorMessage ?? _ctrl.erro) != null) ...[
        const SizedBox(height: 14),
        _banner(_login.errorMessage ?? _ctrl.erro!, colors),
      ],
      const SizedBox(height: 20),
      _botao(colors, 'Entrar', loading, _fazerLogin),
    ]);
  }

  // ---- Etapa 2: formulário -------------------------------------------------
  Widget _cardForm(AppColors colors) {
    final loading = _ctrl.loading;
    final caixa = _ctrl.caixa;
    return _card(colors, [
      _titulo(
        colors,
        LucideIcons.monitor,
        'Dados do terminal',
        'Informe o caixa (code da etiqueta) e um rótulo.',
      ),
      const SizedBox(height: 20),
      _label('Código do caixa', colors),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _codeCaixaCtrl,
              enabled: !loading,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => _ctrl.clearErrorSuave(),
              onSubmitted: (v) => _ctrl.resolverCaixa(v),
              style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 15),
              decoration: _input(colors, hint: 'PDV-01'),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: _botaoSecundario(
              colors,
              'Verificar',
              loading,
              () => _ctrl.resolverCaixa(_codeCaixaCtrl.text),
            ),
          ),
        ],
      ),
      if (caixa != null) ...[
        const SizedBox(height: 12),
        _caixaResolvido(colors, caixa.resumo),
      ],
      const SizedBox(height: 16),
      _label('Rótulo do terminal', colors),
      const SizedBox(height: 6),
      TextField(
        controller: _rotuloCtrl,
        enabled: !loading && caixa != null,
        maxLength: 120,
        style: TextStyle(fontSize: 15, color: colors.text),
        decoration: _input(colors, hint: 'Caixa 03 - Loja Centro'),
      ),
      if (_ctrl.erro != null) ...[
        const SizedBox(height: 8),
        _banner(_ctrl.erro!, colors),
      ],
      const SizedBox(height: 12),
      _botao(
        colors,
        'Emitir token',
        loading,
        caixa == null
            ? null
            : () => _ctrl.emitir(deviceLabel: _rotuloCtrl.text),
      ),
    ]);
  }

  // ---- Etapa 3: token / QR -------------------------------------------------
  Widget _cardToken(AppColors colors) {
    final tok = _ctrl.token!;
    return _card(colors, [
      _titulo(
        colors,
        LucideIcons.qrCode,
        'Token gerado',
        'Leia o QR no terminal para ativá-lo. Uso único.',
      ),
      const SizedBox(height: 20),
      Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: tok.enrollmentToken,
            version: QrVersions.auto,
            size: 240,
            backgroundColor: Colors.white,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _avisoValidade(colors, tok.expiresAt),
      const SizedBox(height: 12),
      _tokenTexto(colors, tok.enrollmentToken),
      const SizedBox(height: 20),
      _botaoSecundario(colors, 'Emitir outro', false, _ctrl.novaEmissao),
      const SizedBox(height: 10),
      _botao(
        colors,
        'Ativar neste terminal',
        false,
        () => Modular.to.navigate('/ativar-terminal/'),
      ),
    ]);
  }

  // ---- helpers de UI (enxutos; reaproveitam o padrão das telas de auth) ----

  Widget _card(AppColors colors, List<Widget> children) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: colors.border),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _titulo(AppColors colors, IconData icon, String t, String sub) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colors.accent),
              const SizedBox(width: 10),
              Text(
                t,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontSize: 12.5, color: colors.textMute)),
        ],
      );

  Widget _caixaResolvido(AppColors colors, String resumo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: colors.success.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: colors.success.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(LucideIcons.circleCheck, size: 16, color: colors.success),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            resumo,
            style: TextStyle(fontSize: 12.5, color: colors.success),
          ),
        ),
      ],
    ),
  );

  Widget _avisoValidade(AppColors colors, DateTime expiresAt) {
    final restante = expiresAt.difference(DateTime.now().toUtc());
    final min = restante.inMinutes.clamp(0, 999);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.warnTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.clock, size: 16, color: colors.warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Válido por ~$min min · uso único. Não recuperável após fechar.',
              style: TextStyle(fontSize: 12, color: colors.warn),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tokenTexto(AppColors colors, String token) => GestureDetector(
    onTap: () => Clipboard.setData(ClipboardData(text: token)),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              token,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: colors.textMute,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(LucideIcons.copy, size: 16, color: colors.textMute),
        ],
      ),
    ),
  );

  Widget _label(String t, AppColors colors) => Text(
    t,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: colors.textMute,
    ),
  );

  Widget _botao(
    AppColors colors,
    String txt,
    bool loading,
    VoidCallback? onTap,
  ) => Material(
    color: onTap == null ? colors.surface3 : colors.accent,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        child: loading
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(colors.accentInk),
                ),
              )
            : Text(
                txt,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: onTap == null ? colors.textMute : colors.accentInk,
                ),
              ),
      ),
    ),
  );

  Widget _botaoSecundario(
    AppColors colors,
    String txt,
    bool loading,
    VoidCallback? onTap,
  ) => Material(
    color: colors.surface2,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          txt,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.text,
          ),
        ),
      ),
    ),
  );

  InputDecoration _input(
    AppColors colors, {
    required String hint,
    Widget? suffix,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: colors.textDim),
    suffixIcon: suffix,
    counterText: '',
    filled: true,
    fillColor: colors.surface2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.accent, width: 1.5),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.borderSoft),
    ),
  );

  Widget _banner(String msg, AppColors colors) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: colors.danger.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: colors.danger.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(LucideIcons.circleAlert, size: 16, color: colors.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            msg,
            style: TextStyle(fontSize: 12.5, color: colors.danger),
          ),
        ),
      ],
    ),
  );
}
