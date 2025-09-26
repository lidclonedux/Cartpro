// lib/screens/admin/tabs/categories/dialogs/category_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../providers/product_provider.dart';
import '../../../../../models/category.dart';
import '../../../widgets/admin_snackbar_utils.dart';
import '../../../../../utils/logger.dart';

class CategoryDialog {
  static void show(BuildContext context, {Category? category}) {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final formKey = GlobalKey<FormState>();

    Logger.info('CategoryDialog: ${isEditing ? 'Editando' : 'Criando'} categoria${isEditing ? ' "${category!.name}"' : ''}');

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23272A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9147FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEditing ? Icons.edit : Icons.add,
                  color: const Color(0xFF9147FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isEditing ? 'Editar Categoria' : 'Nova Categoria',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isEditing) ...[
                    const Text(
                      'Editando categoria existente:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            category!.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            category.name,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Novo nome da categoria:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nome da Categoria',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Ex: Eletrônicos, Roupas, Livros...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(
                        Icons.category,
                        color: Color(0xFF9147FF),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF9147FF)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'O nome da categoria é obrigatório';
                      }
                      if (value.trim().length < 2) {
                        return 'O nome deve ter pelo menos 2 caracteres';
                      }
                      if (value.trim().length > 50) {
                        return 'O nome deve ter no máximo 50 caracteres';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.words,
                    maxLength: 50,
                  ),
                  if (!isEditing) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.green, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Um emoji será automaticamente atribuído à categoria',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Logger.info('CategoryDialog: Diálogo de categoria cancelado');
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => _saveCategory(
                dialogContext,
                formKey,
                nameController.text.trim(),
                isEditing,
                category,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9147FF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isEditing ? Icons.save : Icons.add, size: 16),
                  const SizedBox(width: 8),
                  Text(isEditing ? 'Salvar' : 'Criar'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _saveCategory(
    BuildContext dialogContext,
    GlobalKey<FormState> formKey,
    String categoryName,
    bool isEditing,
    Category? category,
  ) async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    Logger.info('CategoryDialog: Salvando categoria "$categoryName"${isEditing ? ' (editando)' : ' (nova)'}');

    final productProvider = Provider.of<ProductProvider>(dialogContext, listen: false);

    // INÍCIO DA CORREÇÃO
    // O bloco `try/catch` geral foi movido para envolver a lógica de negócio
    // e determinar o sucesso da operação.
    try {
      bool success; // A variável `success` é declarada aqui.

      if (isEditing && category != null) {
        // A lógica de edição permanece a mesma, pois `updateCategory` já retorna um bool.
        final updatedCategory = category.copyWith(name: categoryName);
        success = await productProvider.updateCategory(updatedCategory);
      } else {
        // CORREÇÃO PRINCIPAL APLICADA AQUI
        // Envolvemos a chamada `addCategory` em seu próprio `try/catch` para
        // simular um retorno booleano.
        try {
          await productProvider.addCategory(categoryName);
          // Se a linha acima for executada sem erros, consideramos sucesso.
          success = true;
        } catch (e) {
          // Se `addCategory` lançar uma exceção, consideramos falha.
          success = false;
          // O erro já será tratado pelo `catch` externo, então não precisamos fazer mais nada aqui.
          // Relançamos o erro para que o bloco catch externo possa logá-lo e mostrar a SnackBar.
          rethrow;
        }
      }

      // A verificação de sucesso/falha permanece a mesma.
      if (dialogContext.mounted) {
        if (success) {
          Logger.info('CategoryDialog: Categoria "$categoryName" salva com sucesso');
          Navigator.of(dialogContext).pop();
          
          AdminSnackBarUtils.showSuccess(
            dialogContext,
            isEditing 
              ? 'Categoria atualizada com sucesso!'
              : 'Categoria criada com sucesso!',
          );
        } else {
          // Este bloco agora só será alcançado se `updateCategory` retornar `false`.
          Logger.error('CategoryDialog: Falha ao salvar categoria "$categoryName"');
          AdminSnackBarUtils.showError(
            dialogContext,
            productProvider.errorMessage ?? 
              (isEditing 
                ? 'Erro ao atualizar categoria' 
                : 'Erro ao criar categoria'),
          );
        }
      }
    } catch (e) {
      // Este bloco `catch` agora captura exceções tanto de `updateCategory` quanto de `addCategory`.
      Logger.error('CategoryDialog: Exceção ao salvar categoria "$categoryName"', error: e);
      
      if (dialogContext.mounted) {
        AdminSnackBarUtils.showError(
          dialogContext,
          // Usamos a mensagem de erro do provider se disponível, senão uma mensagem genérica.
          productProvider.errorMessage ?? 'Erro inesperado: ${e.toString()}',
        );
      }
    }
    // FIM DA CORREÇÃO
  }
}
