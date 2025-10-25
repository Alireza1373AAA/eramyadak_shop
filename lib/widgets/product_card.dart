import 'package:flutter/material.dart';

class ProductCard extends StatelessWidget {
  final Map<String,dynamic> p;
  final VoidCallback onTap;
  const ProductCard({super.key, required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = ((p['images'] as List?)?.isNotEmpty ?? false) ? p['images'][0]['src'] as String : null;
    final name = (p['name']??'').toString();
    final price = (p['price']??'').toString();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap:onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children:[
        AspectRatio(aspectRatio:1, child: image!=null? Image.network(image,fit:BoxFit.cover): const Icon(Icons.image,size:48)),
        Padding(padding: const EdgeInsets.all(8), child: Text(name, maxLines:2, overflow:TextOverflow.ellipsis, textAlign: TextAlign.right)),
        Padding(padding: const EdgeInsets.only(right:8,left:8,bottom:8), child: Text(price.isEmpty? '—' : 'قیمت: $price', style: const TextStyle(fontWeight: FontWeight.bold))),
      ])),
    );
  }
}