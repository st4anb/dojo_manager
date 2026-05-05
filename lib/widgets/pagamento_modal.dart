import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/theme/app_theme.dart';

class PagamentoModal extends StatefulWidget {
  final double valorMensalidade; // Valor vindo do perfil do aluno (ex: 75.0)
  final double valorMinimo; // Valor mínimo aceito (vem da config global)
  final Function(double valor) onConfirm;

  const PagamentoModal({
    super.key, 
    required this.valorMensalidade,
    this.valorMinimo = 1.0, // R$ 1,00 padrão para testes
    required this.onConfirm,
  });

  @override
  State<PagamentoModal> createState() => _PagamentoModalState();
}

class _PagamentoModalState extends State<PagamentoModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _valorController;

  @override
  void initState() {
    super.initState();
    // Inicia com o valor padrão do aluno ou valorMinimo como fallback
    double valorInicial = widget.valorMensalidade > 0 ? widget.valorMensalidade : widget.valorMinimo;
    _valorController = TextEditingController(text: valorInicial.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardDarkGrey,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32, // Ajuste para o teclado
        left: 24, 
        right: 24, 
        top: 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.coins, color: AppTheme.accentGold),
                const SizedBox(width: 12),
                Text(
                  "Confirmar Pagamento",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Você pode ajustar o valor para pagamentos parciais ou adiantamentos, desde que respeite o mínimo de R\$ ${widget.valorMinimo.toStringAsFixed(2).replaceAll('.', ',')}.",
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _valorController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "Valor do Pagamento",
                labelStyle: const TextStyle(color: AppTheme.accentGold),
                prefixText: "R\$ ",
                prefixStyle: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: AppTheme.backgroundBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.accentGold, width: 2),
                ),
                errorStyle: const TextStyle(color: Colors.redAccent),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return "Insira um valor";
                final valorDigitado = double.tryParse(value.replaceAll(',', '.'));
                if (valorDigitado == null) return "Valor inválido";
                if (valorDigitado < widget.valorMinimo) return "O valor mínimo é R\$ ${widget.valorMinimo.toStringAsFixed(2).replaceAll('.', ',')}";
                return null;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final valorFinal = double.parse(_valorController.text.replaceAll(',', '.'));
                  Navigator.pop(context);
                  widget.onConfirm(valorFinal);
                }
              },
              child: const Text(
                "GERAR PIX", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
