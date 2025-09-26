import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
// import '../providers/auth_provider.dart'; // Comentado pois não estava sendo usado diretamente aqui.
import '../models/product.dart';
import '../models/category.dart'; // Importação necessária para usar o objeto Category.
import '../utils/logger.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _searchQuery = '';
  // ATUALIZAÇÃO: Agora armazenamos o ID da categoria selecionada, não o nome.
  // 'Todos' é um valor especial para não aplicar filtro.
  String _selectedCategoryId = 'Todos';

  @override
  void initState() {
    super.initState();
    // Atrasar um pouco o carregamento para garantir que o contexto esteja pronto.
    Future.microtask(() => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    // Carrega tanto os produtos quanto as categorias para os filtros.
    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      // ATUALIZAÇÃO: Chama o método refresh que carrega ambos, produtos e categorias.
      await productProvider.refresh();
    } catch (e) {
      Logger.error('Error loading initial data for ProductsScreen', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: ${e.toString()}'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                if (productProvider.isLoading && productProvider.products.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF9147FF),
                    ),
                  );
                }

                if (productProvider.errorMessage != null && productProvider.products.isEmpty) {
                  return _buildErrorState(productProvider.errorMessage!);
                }

                final filteredProducts = _filterProducts(productProvider.products);

                if (filteredProducts.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildProductGrid(filteredProducts);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF23272A),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Barra de pesquisa
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Pesquisar rodas...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF1E1E2C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          
          // Filtro de categoria
          Consumer<ProductProvider>(
            builder: (context, productProvider, child) {
              // ATUALIZAÇÃO: A lista de categorias agora vem do provider.
              // Adicionamos uma categoria "Todos" manualmente no início.
              final List<Category> categories = [
                Category(id: 'Todos', name: 'Todos', context: '', color: '', icon: '', emoji: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
                ...productProvider.categories
              ];
              
              return SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    // ATUALIZAÇÃO: A seleção é baseada no ID da categoria.
                    final isSelected = _selectedCategoryId == category.id;
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            // ATUALIZAÇÃO: Armazena o ID da categoria selecionada.
                            _selectedCategoryId = category.id;
                          });
                        },
                        backgroundColor: const Color(0xFF1E1E2C),
                        selectedColor: const Color(0xFF9147FF),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products) {
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      color: const Color(0xFF9147FF),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color(0xFF23272A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem do produto
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                color: Colors.grey[300],
              ),
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage();
                        },
                      ),
                    )
                  : _buildPlaceholderImage(),
            ),
          ),
          
          // Informações do produto
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // ATUALIZAÇÃO: Usando o getter do modelo para formatação de preço.
                  Text(
                    product.formattedPrice,
                    style: const TextStyle(
                      color: Color(0xFF9147FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Botão de adicionar ao carrinho
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      // ATUALIZAÇÃO: Usando a propriedade `isInStock` vinda da API.
                      onPressed: product.isInStock ? () => _addToCart(product) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9147FF),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        product.isInStock ? 'Adicionar' : 'Sem Estoque',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        color: Colors.grey[300],
      ),
      child: const Center(
        child: Icon(
          Icons.tire_repair,
          size: 48,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.store,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhum produto encontrado',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tente ajustar os filtros de pesquisa',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadInitialData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9147FF),
            ),
            child: const Text('Recarregar'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Erro ao carregar produtos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadInitialData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9147FF),
            ),
            child: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  List<Product> _filterProducts(List<Product> products) {
    return products.where((product) {
      final matchesSearch = _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (product.description.toLowerCase().contains(_searchQuery.toLowerCase()));
      
      // ATUALIZAÇÃO: A lógica de filtro agora usa o `categoryId` do produto.
      final matchesCategory = _selectedCategoryId == 'Todos' ||
          product.categoryId == _selectedCategoryId;
      
      return matchesSearch && matchesCategory;
    }).toList();
  }

  void _addToCart(Product product) {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.addToCart(product);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} adicionado ao carrinho'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Ver Carrinho',
            textColor: Colors.white,
            onPressed: () {
              // Navega para o carrinho (aba 1)
              // A lógica de navegação para a aba do carrinho deve ser implementada
              // na tela principal que contém a BottomNavigationBar.
            },
          ),
        ),
      );
    } catch (e) {
      Logger.error('Error adding product to cart', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao adicionar produto ao carrinho'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
