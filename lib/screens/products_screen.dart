import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../providers/product_provider.dart';
import '../providers/cart_provider.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../utils/logger.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> with TickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedCategoryId = 'Todos';
  Product? _selectedProduct;
  
  // Animation controllers
  late AnimationController _categoryTransitionController;
  late AnimationController _productDetailController;
  late AnimationController _atmosphereController;
  late AnimationController _parallaxController;
  
  // Animations
  late Animation<double> _categoryDepthAnimation;
  late Animation<double> _productScaleAnimation;
  late Animation<double> _atmosphereAnimation;
  late Animation<double> _parallaxAnimation;
  
  // Scroll controllers para cada categoria
  Map<String, ScrollController> _categoryScrollControllers = {};
  late ScrollController _parallaxScrollController;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _categoryTransitionController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _productDetailController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    
    _atmosphereController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    _parallaxController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _parallaxScrollController = ScrollController();
    
    // Setup animations
    _categoryDepthAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _categoryTransitionController,
      curve: Curves.easeOutCubic,
    ));
    
    _productScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _productDetailController,
      curve: Curves.elasticOut,
    ));
    
    _atmosphereAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _atmosphereController,
      curve: Curves.easeInOut,
    ));
    
    _parallaxAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _parallaxController,
      curve: Curves.linear,
    ));
    
    Future.microtask(() => _loadInitialData());
  }

  @override
  void dispose() {
    _categoryTransitionController.dispose();
    _productDetailController.dispose();
    _atmosphereController.dispose();
    _parallaxController.dispose();
    _parallaxScrollController.dispose();
    
    // Dispose scroll controllers
    for (var controller in _categoryScrollControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }

  ScrollController _getScrollController(String categoryId) {
    if (!_categoryScrollControllers.containsKey(categoryId)) {
      _categoryScrollControllers[categoryId] = ScrollController();
    }
    return _categoryScrollControllers[categoryId]!;
  }

  Future<void> _loadInitialData() async {
    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
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

  void _selectCategory(String categoryId) {
    if (categoryId != _selectedCategoryId) {
      setState(() {
        _selectedCategoryId = categoryId;
      });
      _categoryTransitionController.forward(from: 0.0);
    }
  }

  void _showProductDetail(Product product) {
    setState(() {
      _selectedProduct = product;
    });
    _productDetailController.forward(from: 0.0);
  }

  void _hideProductDetail() {
    _productDetailController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _selectedProduct = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          if (productProvider.isLoading && productProvider.products.isEmpty) {
            return _buildLoadingVitrine();
          }

          if (productProvider.errorMessage != null && productProvider.products.isEmpty) {
            return _buildErrorState(productProvider.errorMessage!);
          }

          return _buildVitrineView(productProvider);
        },
      ),
    );
  }

  Widget _buildVitrineView(ProductProvider productProvider) {
    final categories = [
      Category(id: 'Todos', name: 'Todos', context: '', color: '', icon: '', emoji: '🛍️', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      ...productProvider.categories
    ];

    return Stack(
      children: [
        // Fundo profundo com múltiplas camadas de paralaxe
        _buildDeepBackground(),
        
        // Atmosfera e partículas flutuantes
        _buildAtmosphere(),
        
        // Search bar no topo
        _buildSearchBar(),
        
        // Categorias em diferentes profundidades com paralaxe
        ...categories.asMap().entries.map((entry) {
          int index = entry.key;
          Category category = entry.value;
          return _buildCategoryLayer(
            category, 
            productProvider.products,
            index,
            categories.length,
          );
        }).toList(),
        
        // Efeito de vidro da vitrine com reflexos dinâmicos
        _buildAdvancedGlassEffect(),
        
        // Detalhes do produto (overlay)
        if (_selectedProduct != null) _buildProductDetailOverlay(),
      ],
    );
  }

  Widget _buildDeepBackground() {
    return AnimatedBuilder(
      animation: _parallaxAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Camada mais profunda
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..translate(
                  math.sin(_parallaxAnimation.value * 2 * math.pi) * 20,
                  math.cos(_parallaxAnimation.value * 2 * math.pi) * 10,
                  -800.0
                ),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 2.0,
                    colors: [
                      const Color(0xFF0F0F23),
                      const Color(0xFF1A0033),
                      const Color(0xFF000000),
                    ],
                  ),
                ),
              ),
            ),
            
            // Camada intermediária com textura
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..translate(
                  math.cos(_parallaxAnimation.value * 2 * math.pi) * 30,
                  math.sin(_parallaxAnimation.value * 2 * math.pi) * 15,
                  -400.0
                ),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A1A2E).withOpacity(0.3),
                      const Color(0xFF16213E).withOpacity(0.2),
                      const Color(0xFF0F0F23).withOpacity(0.4),
                    ],
                  ),
                ),
              ),
            ),
            
            // Camada próxima ao usuário
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..translate(0.0, 0.0, -100.0),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF000000).withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAtmosphere() {
    return AnimatedBuilder(
      animation: _atmosphereAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Partículas flutuantes
            ...List.generate(12, (index) {
              final offset = Offset(
                (index * 60.0) % MediaQuery.of(context).size.width,
                (index * 80.0) % MediaQuery.of(context).size.height,
              );
              
              return Positioned(
                left: offset.dx + math.sin(_atmosphereAnimation.value * 2 * math.pi + index) * 30,
                top: offset.dy + math.cos(_atmosphereAnimation.value * 2 * math.pi + index) * 20,
                child: Transform(
                  transform: Matrix4.identity()..setEntry(3, 2, 0.001)..translate(0.0, 0.0, -200.0 - (index * 20)),
                  child: Container(
                    width: 4 + (index % 3),
                    height: 4 + (index % 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1 + (index % 3) * 0.05),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            
            // Luz ambiente suave
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 2.0,
                  colors: [
                    Colors.white.withOpacity(0.02 * _atmosphereAnimation.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Transform(
        transform: Matrix4.identity()..setEntry(3, 2, 0.001)..translate(0.0, 0.0, 50.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar na vitrine...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryLayer(Category category, List<Product> allProducts, int index, int totalCategories) {
    final isSelected = _selectedCategoryId == category.id;
    final filteredProducts = _filterProductsByCategory(allProducts, category.id);
    
    // Profundidade dramática baseada na seleção
    double baseZTranslate = isSelected ? 0 : -300.0;
    double categorySpacing = isSelected ? 0 : (index - totalCategories/2) * 100.0;
    double zTranslate = baseZTranslate + categorySpacing;
    
    // Escala mais dramática para criar profundidade real
    double scale = isSelected ? 1.0 : 0.4 - ((index - totalCategories/2).abs() * 0.05);
    double opacity = isSelected ? 1.0 : 0.15;
    double blur = isSelected ? 0.0 : 8.0 + ((index - totalCategories/2).abs() * 3);

    return AnimatedBuilder(
      animation: _categoryDepthAnimation,
      builder: (context, child) {
        return Positioned.fill(
          top: 100,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0008) // Mais perspective
              ..translate(0.0, 0.0, zTranslate * (1.0 + _categoryDepthAnimation.value))
              ..scale(scale),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: opacity,
              child: GestureDetector(
                onTap: isSelected ? null : () => _selectCategory(category.id),
                child: Container(
                  margin: EdgeInsets.all(isSelected ? 8 : 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? Colors.black.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected 
                              ? const Color(0xFF9147FF).withOpacity(0.6)
                              : Colors.white.withOpacity(0.05),
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: const Color(0xFF9147FF).withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ] : [],
                        ),
                        child: Column(
                          children: [
                            _buildCategoryHeader(category, isSelected),
                            if (isSelected) Expanded(
                              child: _buildProductsGrid(filteredProducts, category.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryHeader(Category category, bool isSelected) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSelected 
            ? [
                const Color(0xFF9147FF).withOpacity(0.4), 
                const Color(0xFF9147FF).withOpacity(0.2),
                const Color(0xFF9147FF).withOpacity(0.1),
              ]
            : [
                Colors.grey.withOpacity(0.1),
                Colors.transparent,
              ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (category.emoji.isNotEmpty) 
            Text(
              category.emoji, 
              style: TextStyle(
                fontSize: isSelected ? 28 : 20,
              ),
            ),
          if (category.emoji.isNotEmpty) const SizedBox(width: 12),
          Text(
            category.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSelected ? 28 : 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
              shadows: isSelected ? [
                Shadow(
                  color: const Color(0xFF9147FF).withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ] : [],
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 12),
            Icon(
              Icons.keyboard_arrow_down, 
              color: Colors.white,
              size: 28,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductsGrid(List<Product> products, String categoryId) {
    if (products.isEmpty) {
      return _buildEmptyCategory();
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      color: const Color(0xFF9147FF),
      child: GridView.builder(
        controller: _getScrollController(categoryId),
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65, // Aumentado para dar mais espaço ao botão
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildProductCard(product, index);
        },
      ),
    );
  }

  Widget _buildProductCard(Product product, int index) {
    return Hero(
      tag: 'product_${product.id}',
      child: GestureDetector(
        onTap: () => _showProductDetail(product),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 400 + (index * 100)),
          curve: Curves.easeOutBack,
          child: Card(
            elevation: 12,
            shadowColor: const Color(0xFF9147FF).withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: const Color(0xFF1A1A2E).withOpacity(0.9),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product image - proporção fixa
                      Expanded(
                        flex: 5, // Aumentado
                        child: Container(
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: _buildProductImage(product),
                          ),
                        ),
                      ),
                      
                      // Product info - espaço garantido
                      Container(
                        height: 120, // Altura fixa para evitar overflow
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Nome do produto
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
                            const SizedBox(height: 6),
                            
                            // Preço
                            Text(
                              product.formattedPrice,
                              style: const TextStyle(
                                color: Color(0xFF9147FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Botão sempre visível
                            SizedBox(
                              width: double.infinity,
                              height: 36, // Altura fixa
                              child: ElevatedButton(
                                onPressed: product.isInStock ? () => _addToCart(product) : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: product.isInStock 
                                    ? const Color(0xFF9147FF)
                                    : Colors.grey.withOpacity(0.3),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: product.isInStock ? 6 : 0,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(Product product) {
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return Stack(
        children: [
          Image.network(
            product.imageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholderImage();
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildImageSkeleton();
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.1),
                ],
              ),
            ),
          ),
        ],
      );
    }
    
    return _buildPlaceholderImage();
  }

  Widget _buildImageSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: const Color(0xFF9147FF).withOpacity(0.5),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[700]!,
            Colors.grey[800]!,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.tire_repair,
          size: 48,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _buildAdvancedGlassEffect() {
    return AnimatedBuilder(
      animation: Listenable.merge([_atmosphereAnimation, _parallaxAnimation]),
      builder: (context, child) {
        return Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [
                    0.0,
                    0.2 + (_atmosphereAnimation.value * 0.3),
                    0.5 + (_parallaxAnimation.value * 0.2),
                    0.8,
                    1.0,
                  ],
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.25 * _atmosphereAnimation.value),
                    Colors.cyan.withOpacity(0.05 * _parallaxAnimation.value),
                    Colors.white.withOpacity(0.03),
                    Colors.transparent,
                  ],
                ),
              ),
              child: CustomPaint(
                painter: GlassReflectionPainter(
                  animation1: _atmosphereAnimation.value,
                  animation2: _parallaxAnimation.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductDetailOverlay() {
    return AnimatedBuilder(
      animation: _productScaleAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: GestureDetector(
            onTap: _hideProductDetail,
            child: Container(
              color: Colors.black.withOpacity(0.85 * _productScaleAnimation.value),
              child: Center(
                child: Transform.scale(
                  scale: _productScaleAnimation.value,
                  child: Hero(
                    tag: 'product_${_selectedProduct!.id}',
                    child: _buildProductDetailCard(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductDetailCard() {
    if (_selectedProduct == null) return const SizedBox.shrink();
    
    final product = _selectedProduct!;
    
    return Container(
      margin: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 650),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9147FF).withOpacity(0.4),
            blurRadius: 30,
            spreadRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () => _showFullScreenImage(product),
                child: Container(
                  width: double.infinity,
                  child: _buildProductImage(product),
                ),
              ),
            ),
            
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    Text(
                      product.formattedPrice,
                      style: const TextStyle(
                        color: Color(0xFF9147FF),
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    if (product.description.isNotEmpty) ...[
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            product.description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else const Spacer(),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _hideProductDetail(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.withOpacity(0.3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Voltar'),
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: product.isInStock 
                              ? () {
                                  _addToCart(product);
                                  _hideProductDetail();
                                }
                              : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9147FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 10,
                            ),
                            child: Text(
                              product.isInStock ? 'Adicionar ao Carrinho' : 'Sem Estoque',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(Product product) {
    if (product.imageUrl == null || product.imageUrl!.isEmpty) return;
    
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.9),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Center(
                child: Hero(
                  tag: 'fullscreen_${product.id}',
                  child: InteractiveViewer(
                    child: Image.network(
                      product.imageUrl!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingVitrine() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 2.0,
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF000000),
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF9147FF),
              strokeWidth: 3,
            ),
            SizedBox(height: 28),
            Text(
              'Preparando a vitrine...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Organizando os produtos para você',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCategory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 52,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Categoria vazia',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Aguardando novos produtos',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 2.0,
          colors: [
            const Color(0xFF2E1A1A),
            const Color(0xFF000000),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Erro na vitrine',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                error,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _loadInitialData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9147FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 8,
              ),
              child: const Text(
                'Tentar Novamente',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Product> _filterProductsByCategory(List<Product> products, String categoryId) {
    List<Product> filtered = products.where((product) {
      final matchesSearch = _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (product.description.toLowerCase().contains(_searchQuery.toLowerCase()));
      
      final matchesCategory = categoryId == 'Todos' ||
          product.categoryId == categoryId;
      
      return matchesSearch && matchesCategory;
    }).toList();
    
    return filtered;
  }

  void _addToCart(Product product) {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.addToCart(product);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Produto adicionado!',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(20),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Ver Carrinho',
            textColor: const Color(0xFF9147FF),
            backgroundColor: Colors.white.withOpacity(0.1),
            onPressed: () {
              // Navigation logic should be handled by parent widget
            },
          ),
        ),
      );
    } catch (e) {
      Logger.error('Error adding product to cart', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(Icons.error, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Erro ao adicionar produto ao carrinho',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  }
}

// Custom painter para efeitos de vidro avançados
class GlassReflectionPainter extends CustomPainter {
  final double animation1;
  final double animation2;

  GlassReflectionPainter({
    required this.animation1,
    required this.animation2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.1 * animation1),
          Colors.cyan.withOpacity(0.05 * animation2),
          Colors.white.withOpacity(0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Desenha reflexos diagonais
    final path = Path();
    final reflectionWidth = size.width * 0.3;
    final reflectionHeight = size.height * 0.8;
    
    final startX = (size.width * animation1) - reflectionWidth;
    
    path.moveTo(startX, 0);
    path.lineTo(startX + reflectionWidth, 0);
    path.lineTo(startX + reflectionWidth * 0.7, reflectionHeight);
    path.lineTo(startX - reflectionWidth * 0.3, reflectionHeight);
    path.close();

    canvas.drawPath(path, paint);
    
    // Segundo reflexo com movimento diferente
    final paint2 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [
          Colors.white.withOpacity(0.05 * animation2),
          Colors.blue.withOpacity(0.02 * animation1),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path2 = Path();
    final startX2 = size.width - (size.width * animation2);
    
    path2.moveTo(startX2, size.height * 0.2);
    path2.lineTo(startX2 + reflectionWidth * 0.5, size.height * 0.2);
    path2.lineTo(startX2 + reflectionWidth * 0.3, size.height);
    path2.lineTo(startX2 - reflectionWidth * 0.2, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
