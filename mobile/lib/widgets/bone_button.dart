import 'package:flutter/material.dart';

class BoneButton extends StatelessWidget {
  const BoneButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = 160,
    this.height = 48,
    this.tinted = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final double width;
  final double height;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final base = Image.asset(
      'assets/ui/bone.png', // <- you renamed it to bone.png
      fit: BoxFit.contain,
      color: tinted
          ? (enabled
              ? Colors.white
              : Colors.white.withOpacity(0.6)) // subtle disabled look
          : null,
      colorBlendMode: tinted ? BlendMode.srcATop : null,
    );

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(height / 2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // Purple pill behind the bone for contrast/size consistency
              Container(color: Theme.of(context).colorScheme.primary),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: base,
              ),
              Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
