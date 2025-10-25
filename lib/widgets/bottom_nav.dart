import 'package:flutter/material.dart';
import '../app_theme.dart';

class YellowBottomNav extends StatelessWidget {
  final int index; final ValueChanged<int> onTap;
  const YellowBottomNav({super.key, required this.index, required this.onTap});
  @override
  Widget build(BuildContext context){
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: AppTheme.brandYellow, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
          _item(Icons.person, 4),
          _item(Icons.headset_mic, 3),
          _fab(),
          _item(Icons.home_outlined, 1),
          _item(Icons.grid_view, 0),
        ]),
      ),
    );
  }
  Widget _item(IconData icon, int i)=> IconButton(onPressed:()=>onTap(i), icon: Icon(icon, color: index==i? Colors.black: Colors.black54));
  Widget _fab()=> Container(
    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]),
    child: IconButton(onPressed: ()=>onTap(2), icon: const Icon(Icons.shopping_cart))
  );
}