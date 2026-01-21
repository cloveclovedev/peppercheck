import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';

class ImageGridPicker extends StatelessWidget {
  final List<XFile> images;
  final VoidCallback onAddClick;
  final ValueChanged<int> onRemoveClick;
  final int maxImages;

  const ImageGridPicker({
    super.key,
    required this.images,
    required this.onAddClick,
    required this.onRemoveClick,
    this.maxImages = 5,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length < maxImages ? images.length + 1 : images.length,
      itemBuilder: (context, index) {
        if (index < images.length) {
          return _buildImageItem(context, index);
        } else {
          return _buildAddButton(context);
        }
      },
    );
  }

  Widget _buildImageItem(BuildContext context, int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: FileImage(File(images[index].path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () => onRemoveClick(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return InkWell(
      onTap: onAddClick,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Icon(
            Icons.add_a_photo,
            color: AppColors.textSecondary,
            size: 24,
          ),
        ),
      ),
    );
  }
}
