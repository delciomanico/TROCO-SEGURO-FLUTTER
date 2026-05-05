# Guia do Novo FeedbackService

## Problema Resolvido

Os pop-ups de feedback (snackbars) estavam ficando por baixo dos modais e na parte inferior da tela. Isso acontecia porque o `ScaffoldMessenger` estava vinculado ao contexto da `Scaffold`, e quando um modal era aberto, o snackbar acabava atrás dele.

## Solução Implementada

Foi criado um novo **`FeedbackService`** que utiliza `OverlayEntry` do Flutter para garantir que os feedbacks **sempre apareçam no topo de tudo**, incluindo acima de modais, diálogos e qualquer outro overlay.

## Características do FeedbackService

✅ **Sempre aparece acima de modais e diálogos**
✅ **Design moderno e visível**
✅ **Animações suaves**
✅ **Posições configuráveis** (topo, fundo)
✅ **Três tipos de feedback** (sucesso, erro, info)
✅ **Auto-desaparece** após um tempo

## Como Usar

### 1. Feedback de Sucesso

```dart
FeedbackService.showSuccess(
  context,
  message: 'Cartão criado com sucesso!',
  duration: const Duration(seconds: 3),
);
```

### 2. Feedback de Erro

```dart
FeedbackService.showError(
  context,
  message: 'Erro ao realizar operação. Tente novamente.',
  duration: const Duration(seconds: 4),
);
```

### 3. Feedback de Informação

```dart
FeedbackService.showInfo(
  context,
  message: 'Operação em andamento...',
  duration: const Duration(seconds: 3),
);
```

### 4. Feedback Genérico (customizado)

```dart
FeedbackService.show(
  context,
  message: 'Sua mensagem aqui',
  type: 'success', // 'success', 'error', 'info'
  duration: const Duration(seconds: 3),
);
```

## Posições Disponíveis

Por padrão, o feedback aparece no **topo** da tela. Você pode mudar para:

```dart
FeedbackService.showSuccess(
  context,
  message: 'Mensagem',
  position: FeedbackPosition.top,    // Padrão - topo da tela
);

FeedbackService.showSuccess(
  context,
  message: 'Mensagem',
  position: FeedbackPosition.bottom, // Fundo da tela
);
```

## Arquivos Modificados

### 1. Criado
- `lib/services/feedback_service.dart` - Novo serviço centralizado

### 2. Atualizados
- `lib/main.dart` - Substituído `ScaffoldMessenger` por `FeedbackService`
- `lib/widgets/virtual_cards_modal.dart` - Substituído `ScaffoldMessenger` por `FeedbackService`
- `lib/screens/profile_screen.dart` - Substituído `ScaffoldMessenger` por `FeedbackService`

## Cores e Estilos

As cores utilizadas são:

- **Sucesso**: Verde (#10B981)
- **Erro**: Vermelho (#EF4444)
- **Info**: Azul (#3B82F6)

## Exemplo Completo em um Modal

```dart
showModalBottomSheet(
  context: context,
  builder: (_) => Container(
    child: Column(
      children: [
        Text('Meu Modal'),
        ElevatedButton(
          onPressed: () {
            // Realizar ação
            FeedbackService.showSuccess(
              context,
              message: 'Ação realizada com sucesso!',
            );
          },
          child: const Text('Confirmar'),
        ),
      ],
    ),
  ),
);
```

## Quando o Feedback Desaparece

- **Automático**: Após a duração especificada (padrão: 3-4 segundos)
- **Manual**: Um novo feedback substitui o anterior automaticamente
- **Seguro**: Se o contexto for desmontado, o feedback é removido com segurança

## Integração com SuccessModal

O novo `FeedbackService` pode ser usado conjuntamente com o `SuccessModal` para diferentes tipos de feedback:

- Use `FeedbackService` para mensagens **rápidas e discretas**
- Use `SuccessModal` para **confirmações importantes** que precisam de interação do usuário

## Benefícios

1. **Melhor UX**: Usuário vê os feedbacks acima de tudo
2. **Consistência**: Todos os feedbacks usam o mesmo sistema
3. **Manutenibilidade**: Mudanças de styling em um único lugar
4. **Performance**: Gerenciamento automático de ciclo de vida
5. **Acessibilidade**: Melhor visibilidade para usuários

---

**Implementado em**: Fevereiro 2026
**Versão**: 1.0
