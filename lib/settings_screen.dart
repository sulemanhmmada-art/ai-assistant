import 'dart:ui';
import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final VoidCallback onNewChat;
  final VoidCallback onOpenSettings;

  const AppDrawer({
    super.key,
    required this.onNewChat,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF070913).withOpacity(0.85),
            border: Border(
              left: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 1. رأس القائمة - زر محادثة جديدة بتدرج نيون
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onNewChat();
                      },
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: const Text(
                        'محادثة جديدة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: const Color(0xFF2563EB).withOpacity(0.4),
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ).copyWith(
                        backgroundBuilder: (context, states, child) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF00D2FF)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: child,
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'المحادثات السابقة',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // 2. قائمة المحادثات القديمة بكروت زجاجية
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      final titles = [
                        'أفكار مشروع ذكاء اصطناعي',
                        'صياغة بريد إلكتروني',
                        'شرح مفهوم Flutter Streams',
                        'تحسين أداء تطبيق الهاتف',
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            tileColor: Colors.white.withOpacity(0.04),
                            leading: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Color(0xFF00D2FF),
                              size: 18,
                            ),
                            title: Text(
                              titles[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white.withOpacity(0.3),
                                size: 18,
                              ),
                              onPressed: () {},
                            ),
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(color: Colors.white10),

                // 3. الجزء السفلي - الإعدادات والمظاهر
                ListTile(
                  leading: const Icon(Icons.settings_outlined, color: Colors.white),
                  title: const Text(
                    'الإعدادات',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onOpenSettings();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
