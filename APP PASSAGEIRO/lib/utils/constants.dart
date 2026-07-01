import 'package:flutter/material.dart';
import 'package:troco_seguro/models/faq_item.dart';

class AppColors {
  // App-wide palette changed to dark/gold identity
  // Primary gold accents and neutral dark backgrounds
  static const Color primaryGold = Color(0xFFD4AF37); // dark theme accent (gold)
  static const Color secondaryGold = Color(0xFFC5A028);

  // Light theme accent — orange from the app logo icon
  static const Color primaryOrange = Color(0xFFFF6600);
  static const Color secondaryOrange = Color(0xFFE55A00);

  // Backgrounds / surfaces
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF2F2F2);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);

  // Text
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF121212);

  // Subtle borders
  static const Color cardBorder = Color(0xFFE6E6E6);

  // Gradients using gold tones
  static const List<Color> gradientColors = [primaryGold, secondaryGold];
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGold, secondaryGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Silver / light-card gradient used for cards in light mode
  static const LinearGradient silverGradient = LinearGradient(
    colors: [Color(0xFFF7F8FA), Color(0xFFEFEFF2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Backwards-compatible aliases for existing code ---
  static const Color accent = primaryGold;
  static const Color primary = primaryGold;
  static const Color secondary = secondaryGold;
  static const Color background = lightBackground;
  static const Color card = lightCard;
  static const Color text = textDark;
  static const Color textSecondary = Color(0xFF5A6B7D);

  static const Color darkBlue = primaryGold;
  static const Color darkBlueSurface = darkCard;
  static const Color darkBlueLight = secondaryGold;

  static const LinearGradient darkBlueGradient = LinearGradient(
    colors: [darkBlue, darkBlueSurface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Retorna a cor de acento correta para o tema atual (laranja no claro, dourado no escuro)
  static Color accentOf(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? primaryGold : primaryOrange;
  }

  // Retorna a cor de acento secundária correta para o tema atual
  static Color secondaryAccentOf(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? secondaryGold : secondaryOrange;
  }

  // Retorna gradiente de acento correto para o tema atual
  static LinearGradient accentGradientOf(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? primaryGradient
        : const LinearGradient(
            colors: [primaryOrange, secondaryOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
  }
}

class Constants {
  // URL base da API
  static const String apiBaseUrl = 'https://trocoseguro.wemof.tech';

  static final List<FAQItem> faqData = [
    FAQItem(
      question: "Como pago o táxi?",
      answer:
          "Aponte a câmera para o QR Code que o motorista possui no painel ou no telefone dele. Confirme o valor e insira seu PIN.",
    ),
    FAQItem(
      question: "Como carrego minha carteira?",
      answer:
          "Vá em Carteira > Carregar, escolha o valor e gere uma referência. Pague no Multicaixa ou MCX Express.",
    ),
    FAQItem(
      question: "O que são os cartões virtuais?",
      answer:
          "São sub-contas onde você pode definir um saldo específico para filhos ou funcionários usarem sem acesso à sua carteira principal.",
    ),
    FAQItem(
      question: "É seguro?",
      answer:
          "Sim! Todas as transações exigem seu PIN pessoal e os dados são criptografados seguindo normas bancárias.",
    ),
  ];
}
