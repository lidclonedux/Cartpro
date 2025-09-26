// lib/screens/home_screen.dart - VERSÃO SIMPLIFICADA E CORRIGIDA

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import 'products_screen.dart';
import 'cart_screen.dart';
import 'my_orders_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Lista de telas para o cliente
  static const List<Widget> _widgetOptions = <Widget>[
    ProductsScreen(),
    CartScreen(),
    MyOrdersScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // O corpo da tela muda com base no item selecionado na barra de navegação
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      // A barra de navegação é sempre a mesma para o cliente
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Vitrine',
          ),
          BottomNavigationBarItem(
            icon: Consumer<CartProvider>(
              builder: (context, cart, child) {
                // O Badge mostra um indicador numérico sobre o ícone
                return Badge(
                  label: Text('${cart.itemCount}'),
                  isLabelVisible: cart.isNotEmpty,
                  child: const Icon(Icons.shopping_cart),
                );
              },
            ),
            label: 'Carrinho',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Meus Pedidos',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF23272A),
        selectedItemColor: const Color(0xFF9147FF),
        unselectedItemColor: Colors.white54,
      ),
    );
  }
}
