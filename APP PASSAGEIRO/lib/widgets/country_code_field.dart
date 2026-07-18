import 'package:flutter/material.dart';
import 'package:troco_seguro/utils/constants.dart';

/// Código de país para preenchimento do número de telefone.
class CountryCode {
  final String iso;
  final String dialCode;
  final String flag;
  final String name;

  const CountryCode({
    required this.iso,
    required this.dialCode,
    required this.flag,
    required this.name,
  });
}

/// Lista curada de códigos de país — Angola é o padrão (primeiro da lista),
/// seguido de países vizinhos/lusófonos mais comuns entre os utilizadores.
const List<CountryCode> kCountryCodes = [
  CountryCode(iso: 'AO', dialCode: '244', flag: '🇦🇴', name: 'Angola'),
  CountryCode(iso: 'PT', dialCode: '351', flag: '🇵🇹', name: 'Portugal'),
  CountryCode(iso: 'BR', dialCode: '55', flag: '🇧🇷', name: 'Brasil'),
  CountryCode(iso: 'MZ', dialCode: '258', flag: '🇲🇿', name: 'Moçambique'),
  CountryCode(iso: 'CV', dialCode: '238', flag: '🇨🇻', name: 'Cabo Verde'),
  CountryCode(iso: 'CD', dialCode: '243', flag: '🇨🇩', name: 'Rep. Dem. Congo'),
  CountryCode(iso: 'NA', dialCode: '264', flag: '🇳🇦', name: 'Namíbia'),
  CountryCode(iso: 'ZA', dialCode: '27', flag: '🇿🇦', name: 'África do Sul'),
];

/// Chip tocável que mostra o código de país seleccionado e abre uma lista
/// para o utilizador escolher outro. Pensado para ficar ao lado de um
/// [TextField] de número de telefone (mesma altura/estilo de contorno).
class CountryCodeSelector extends StatelessWidget {
  final CountryCode selected;
  final bool isDark;
  final ValueChanged<CountryCode> onChanged;

  const CountryCodeSelector({
    super.key,
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<CountryCode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CountryPickerSheet(isDark: isDark, selected: selected),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selected.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              '+${selected.dialCode}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: isDark ? Colors.white54 : Colors.black45),
          ],
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatelessWidget {
  final bool isDark;
  final CountryCode selected;

  const _CountryPickerSheet({required this.isDark, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1B1B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Escolha o país',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: kCountryCodes.length,
              itemBuilder: (ctx, i) {
                final c = kCountryCodes[i];
                final isSelected = c.iso == selected.iso;
                return ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    c.name,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  trailing: Text(
                    '+${c.dialCode}',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
