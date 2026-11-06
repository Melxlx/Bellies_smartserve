import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  final String path;
  final String? productName;
  final double? height;
  final double width;
  final BoxFit fit;

  const ProductImage({
    super.key,
    required this.path,
    this.productName,
    this.height,
    this.width = double.infinity,
    this.fit = BoxFit.contain,
  });

  String _resolvedPath() {
    if (productName != null && productName!.isNotEmpty) {
      final name = productName!.toLowerCase();

      if (name.contains('tapsilog')) return 'assets/images/Tapsilog.png';
      if (name.contains('tocilog')) return 'assets/images/Tocilog.png';
      if (name.contains('chicksilog') || name.contains('chicken silog')) return 'assets/images/Chicksilog.png';
      if (name.contains('bangsilog')) return 'assets/images/Bangsilog.png';
      if (name.contains('spamsilog')) return 'assets/images/Spamsilog.png';
      if (name.contains('corned beef')) return 'assets/images/Corned_Beef_Silog.png';
      if (name.contains('hotsilog')) return 'assets/images/Hotsilog.png';
      if (name.contains('sisigsilog')) return 'assets/images/Sisigsilog.png';
      if (name.contains('hungarian')) return 'assets/images/Hungarian_Silog.png';
      if (name.contains('bologna')) return 'assets/images/BolognaSilog.png';
      if (name.contains('porksilog')) return 'assets/images/Porksilog.png';
      if (name.contains('cornsilog')) return 'assets/images/cornsilog.png';
      if (name.contains('hamsilog')) return 'assets/images/hamsilog.png';
      if (name.contains('longsilog')) return 'assets/images/longsilog.png';

      if (name.contains('plain lugaw')) return 'assets/images/Plain_Lugaw.png';
      if (name.contains('lugaw with egg')) return 'assets/images/Lugaw_with_Egg.png';
      if (name.contains('goto')) return 'assets/images/Goto.png';
      if (name.contains('lugaw')) return 'assets/images/Lugaw.png';
      if (name.contains('pares') && name.contains('rice')) return 'assets/images/pares_rice.png';
      if (name.contains('pares')) return 'assets/images/pares.png';
      if (name.contains('mami') && name.contains('rice')) return 'assets/images/mami_rice.png';
      if (name.contains('mami')) return 'assets/images/mami.png';

      if (name.contains('adobo')) return 'assets/images/Adobo.png';
      if (name.contains('buttered chicken')) return 'assets/images/Buttered_Chicken_Wings.png';
      if (name.contains('buffalo')) return 'assets/images/BuffaloWings.png';
      if (name.contains('torta')) return 'assets/images/Torta.png';
      if (name.contains('fish fillet')) return 'assets/images/Sweet_and_SourFish_Fillet.png';
      if (name.contains('sisig barkada') || name.contains('sisigbarkada')) return 'assets/images/sisigbarkada.png';
      if (name.contains('sisig')) return 'assets/images/Sizzling_Sisig_Barkada_Sharing_Platter-25-removebg-preview.png';

      if (name.contains('bihon')) return 'assets/images/Pancit_Bihon.png';
      if (name.contains('canton')) return 'assets/images/Pancit_Canton.png';
      if (name.contains('miki')) return 'assets/images/Pancit_Miki.png';

      if (name.contains('pastilog')) return 'assets/images/Pastilog.png';
      if (name.contains('siomai')) return 'assets/images/Fried_Siomai_Silog.png';

      if (name.contains('jin ramen spicy')) return 'assets/images/Jin_Ramen_Spicy.png';
      if (name.contains('jin ramen mild')) return 'assets/images/Jin_Ramen_Mild.png';
      if (name.contains('buldak carbonara')) return 'assets/images/BuldakCarbonara.png';
      if (name.contains('buldak cheese')) return 'assets/images/BuldakCheese.png';
      if (name.contains('bulgogi')) return 'assets/images/Bulgogi.png';
      if (name.contains('shin ramyun')) return 'assets/images/Shin_Ramyun.png';
      if (name.contains('ramen') || name.contains('korean')) return 'assets/images/korean_noodles.png';

      if (name.contains('fries solo')) return 'assets/images/Fries_Solo.png';
      if (name.contains('sharing')) return 'assets/images/Fries_for_Sharing.png';
      if (name.contains('barkada meal')) return 'assets/images/BarkadaMeal.png';
      if (name.contains('tenders')) return 'assets/images/ChickenTenders_with_Fries.png';
      if (name.contains('shanghai') || name.contains('lumpiang shanghai')) return 'assets/images/Lumpiang_Shanghai.png';

      if (name.contains('water')) return 'assets/images/BottledWater.png';
      if (name.contains('cucumber')) return 'assets/images/Cucumber_Drink.png';
      if (name.contains('1.5') || name.contains('coke 1.5')) return 'assets/images/Coke1.5L.png';
      if (name.contains('mismo')) return 'assets/images/CokeMismo.png';
      if (name.contains('sprite')) return 'assets/images/Sprite.png';
      if (name.contains('royal')) return 'assets/images/royal.png';
      if (name.contains('latte')) return 'assets/images/Spanish_Latte.png';
      if (name.contains('americano')) return 'assets/images/Americano.png';
      if (name.contains('matcha')) return 'assets/images/Matcha.png';

      if (name.contains('egg')) return 'assets/images/BoiledEgg.png';
      if (name.contains('tokwa')) return 'assets/images/Tokwa.png';
      if (name.contains('toge')) return 'assets/images/Lumpiang_Toge.png';
      if (name.contains('crabstick')) return 'assets/images/crabstick.png';
      if (name.contains('gyoza')) return 'assets/images/gyoza.png';
      if (name.contains('mix ball') || name.contains('mix ball')) return 'assets/images/mixball.png';
      if (name.contains('bilao')) return 'assets/images/bilao_pancit.png';
      if (name.contains('cheese')) return 'assets/images/cheese.png';
    }

    final trimmed = path.trim();
    if (trimmed.isNotEmpty) {
      if (trimmed.startsWith('http') || trimmed.startsWith('assets/')) {
        return trimmed;
      }
      return 'assets/images/$trimmed';
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedPath();

    if (resolved.startsWith('http')) {
      return Image.network(
        resolved,
        height: height,
        width: width,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return _buildPlaceholder();
        },
      );
    }

    if (resolved.isNotEmpty) {
      return Image.asset(
        resolved,
        height: height,
        width: width,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      height: height,
      width: width,
      color: Colors.grey[200],
      child: const Icon(Icons.fastfood, size: 50, color: Colors.grey),
    );
  }
}
