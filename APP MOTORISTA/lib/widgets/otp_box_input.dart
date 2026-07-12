import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Input de código OTP em caixas segmentadas (uma por dígito), ligado a um
/// [TextEditingController] normal — mantém-se compatível com toda a lógica
/// existente de validação/submissão que já lê `controller.text`.
class OtpBoxInput extends StatefulWidget {
  final TextEditingController controller;
  final Color accentColor;
  final bool isDark;
  final int length;

  const OtpBoxInput({
    super.key,
    required this.controller,
    required this.accentColor,
    required this.isDark,
    this.length = 6,
  });

  @override
  State<OtpBoxInput> createState() => _OtpBoxInputState();
}

class _OtpBoxInputState extends State<OtpBoxInput> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    _focusNode.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _focusNode.removeListener(_onChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final borderColor =
        widget.isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula a largura de cada caixa a partir do espaço disponível para
        // nunca ultrapassar a largura do ecrã (evita overflow em telas
        // estreitas), com um limite superior para não ficarem enormes em
        // telas largas/tablets.
        const spacing = 8.0;
        // Cada caixa tem margem simétrica (spacing/2 de cada lado), incluindo
        // a primeira e a última — o espaço total ocupado por margens é
        // `spacing * length`, não `spacing * (length - 1)`.
        final totalSpacing = spacing * widget.length;
        final rawWidth = (constraints.maxWidth - totalSpacing) / widget.length;
        final boxWidth = rawWidth > 48.0 ? 48.0 : rawWidth;
        final boxHeight = boxWidth * 1.18;
        final fontSize = (boxWidth * 0.42).clamp(14.0, 20.0);

        return GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.length, (i) {
                  final filled = i < text.length;
                  final isCurrent = i == text.length && _focusNode.hasFocus;
                  return Container(
                    width: boxWidth,
                    height: boxHeight,
                    margin: EdgeInsets.symmetric(horizontal: spacing / 2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent || filled
                            ? widget.accentColor
                            : borderColor,
                        width: isCurrent ? 1.6 : 1.2,
                      ),
                    ),
                    child: Text(
                      filled ? text[i] : '',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  );
                }),
              ),
              Opacity(
                opacity: 0,
                child: SizedBox(
                  width: double.infinity,
                  height: boxHeight,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    maxLength: widget.length,
                    showCursor: false,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
