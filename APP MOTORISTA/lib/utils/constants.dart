import 'package:flutter/material.dart';
import 'package:troco_seguro_pro/models/driver_user.dart';
import 'package:troco_seguro_pro/models/transaction.dart';
import 'package:troco_seguro_pro/models/trip.dart';
import 'package:troco_seguro_pro/models/faq_item.dart';

class AppColors {
  // Paleta alinhada com trocoseguro.wemof.tech (tokens "obsidian"/"ember"/"gold")
  // Dark theme accent trocado de gold para ember (dark) — nomes mantidos por compatibilidade
  static const Color primaryGold = Color(0xFFF07000);
  static const Color secondaryGold = Color(0xFFF07000);

  // Light theme accent
  static const Color primaryOrange = Color(0xFFF07000);
  static const Color secondaryOrange = Color(0xFFF07000);

  // Backwards-compat aliases
  static const Color primaryBlue = primaryGold;
  static const Color secondaryBlue = secondaryGold;

  // Light mode
  static const Color lightBackground = Color(0xFFFFFFFF); // obsidian-lowest (light)
  static const Color lightSurface = Color(0xFFF8F8F8); // obsidian-low (light)
  static const Color lightCard = Color(0xFFF0F0F0); // obsidian-mid (light)
  static const Color lightBorder = Color(0xFFE5E5E5); // obsidian-high (light)

  // Dark mode
  static const Color darkBackground = Color(0xFF0E0E0E); // obsidian-lowest
  static const Color darkSurface = Color(0xFF131313); // obsidian-low
  static const Color darkCard = Color(0xFF1C1B1B); // obsidian-mid
  static const Color darkCardElevated = Color(0xFF201F1F); // obsidian-high

  static const Color textLight = Color(0xFFE5E2E1); // on-surface
  static const Color textDark = Color(0xFF131313); // on-surface (light)
  static const Color textMutedOnDark = Color(0xFFD0C5AF); // on-surface-variant
  static const Color textMutedOnLight = Color(0xFF5E6E82);

  static const Color cardBorder = Color(0xFFE5E5E5); // obsidian-high (light)

  // Backwards-compatible aliases
  static const Color accent = primaryGold;
  static const Color accentLight = secondaryGold;
  static const Color primary = primaryGold;
  static const Color secondary = secondaryGold;
  static const Color background = lightBackground;
  static const Color card = lightCard;
  static const Color text = textDark;
  static const Color textSecondary = Color(0xFF5A6B7D);

  static const Color darkBlue = darkSurface;
  static const Color darkBlueSurface = darkSurface;
  static const Color darkBlueLight = darkCardElevated;

  // Status colors
  static const Color online = Color(0xFF3ECF8E);
  static const Color offline = Color(0xFFE74C3C);
  static const Color pending = Color(0xFFE4B445);
  static const Color success = Color(0xFF3ECF8E);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);

  static const Color statusOnline = online;
  static const Color statusOffline = offline;
  static const Color statusPending = pending;

  // Gradients — dark theme usa gold, ambos usados de forma estática
  static const List<Color> gradientColors = [primaryGold, secondaryGold];

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGold, secondaryGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient earningsGradient = LinearGradient(
    colors: [primaryGold, secondaryGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkScreenGradient = LinearGradient(
    colors: [darkBackground, darkSurface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkBlueGradient = LinearGradient(
    colors: [primaryGold, darkCard],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Cartão de saldo dourado (estilo da 1ª versão do app)
  static const Color walletCardGoldLight = Color(0xFFFFD873);
  static const Color walletCardGoldDark = Color(0xFFC77A00);
  static const LinearGradient walletCardGradient = LinearGradient(
    colors: [walletCardGoldLight, primaryGold, walletCardGoldDark],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Helpers de acento adaptativos (laranja no claro, dourado no escuro) ──────

  /// Acento principal: laranja no tema claro, dourado no tema escuro.
  static Color accentOf(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? primaryGold : primaryOrange;
  }

  /// Acento secundário: versão mais escura do acento principal.
  static Color secondaryAccentOf(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? secondaryGold : secondaryOrange;
  }

  /// Gradiente adaptativo ao tema atual.
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

  /// Compatibilidade com código existente (sempre retorna gold — preferir accentOf).
  static Color adaptiveAccent(BuildContext context) {
    return accentOf(context);
  }
}

class Constants {
  // URL base da API
  static const String apiBaseUrl = 'https://trocoseguro.wemof.tech';

  static final DriverUser mockDriver = DriverUser(
    fullName: 'António Silva',
    phoneNumber: '+244923456789',
    balance: 45000,
    isLoggedIn: false,
    role: 'DRIVER',
    rating: 4.8,
    totalTrips: 156,
    licensePlate: 'LD-45-67-AB',
    vehicleModel: 'Toyota Corolla',
    vehicleColor: 'Branco',
    vehicleYear: '2020',
    isOnline: false,
  );

  static final List<FAQItem> faqData = [
    FAQItem(
      question: "Como recebo pagamentos?",
      answer:
          "Mostre o QR Code na tela inicial para o passageiro escanear. O valor será creditado automaticamente na sua carteira.",
    ),
    FAQItem(
      question: "Como faço saques?",
      answer:
          "Vá em Carteira > Sacar, escolha o valor e o método (transferência bancária ou MCX Express). Os saques são processados em até 24h.",
    ),
    FAQItem(
      question: "O que significa estar Online?",
      answer:
          "Quando você está Online, seu QR Code fica ativo para receber pagamentos. Desligue quando não estiver trabalhando.",
    ),
    FAQItem(
      question: "Como vejo meus ganhos?",
      answer:
          "Na aba Ganhos você vê o resumo diário, semanal e mensal de todos os pagamentos recebidos.",
    ),
    FAQItem(
      question: "É seguro?",
      answer:
          "Sim! Todas as transações são protegidas e você recebe notificação instantânea de cada pagamento.",
    ),
  ];

  static final List<Transaction> mockTransactions = [
    Transaction(
      id: '1',
      type: 'received',
      description: 'Pagamento de viagem',
      amount: 2500,
      date: '10 Jan',
      time: '14:30',
      passengerName: 'Maria Santos',
      status: 'completed',
    ),
    Transaction(
      id: '2',
      type: 'received',
      description: 'Pagamento de viagem',
      amount: 1800,
      date: '10 Jan',
      time: '12:15',
      passengerName: 'João Pedro',
      status: 'completed',
    ),
    Transaction(
      id: '3',
      type: 'withdrawal',
      description: 'Saque para conta bancária',
      amount: -20000,
      date: '09 Jan',
      time: '18:00',
      status: 'completed',
      paymentMethod: 'bank',
    ),
    Transaction(
      id: '4',
      type: 'received',
      description: 'Pagamento de viagem',
      amount: 3200,
      date: '09 Jan',
      time: '10:45',
      passengerName: 'Ana Luísa',
      status: 'completed',
    ),
  ];

  static final List<Trip> mockTrips = [
    Trip(
      id: '1',
      passengerName: 'Maria Santos',
      origin: 'Maianga',
      destination: 'Miramar',
      date: '10 Jan',
      time: '14:30',
      amount: 2500,
      rating: 5.0,
      status: 'completed',
      distance: 5.2,
      duration: 18,
    ),
    Trip(
      id: '2',
      passengerName: 'João Pedro',
      origin: 'Talatona',
      destination: 'Ilha de Luanda',
      date: '10 Jan',
      time: '12:15',
      amount: 1800,
      rating: 4.5,
      status: 'completed',
      distance: 3.8,
      duration: 12,
    ),
    Trip(
      id: '3',
      passengerName: 'Ana Luísa',
      origin: 'Benfica',
      destination: 'Alvalade',
      date: '09 Jan',
      time: '10:45',
      amount: 3200,
      rating: 5.0,
      comment: 'Excelente motorista!',
      status: 'completed',
      distance: 7.5,
      duration: 25,
    ),
  ];
}
