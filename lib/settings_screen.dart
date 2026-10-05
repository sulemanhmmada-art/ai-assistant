import 'dart:ui';
import 'package:flutter/material.dart';
import 'background_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedModel = 'GPT-4o (الأسرع والأذكى)';
  String _selectedLanguage = 'العربية';
  double _fontSize = 15.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // الشريط العلوي
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'الإعدادات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSectionHeader('نموذج الذكاء الاصطناعي'),
                    _buildGlassCard(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedModel,
                          dropdownColor: const Color(0xFF0B0E1E),
                          style: const TextStyle(color: Colors.white),
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF00D2FF)),
                          items: [
                            'GPT-4o (الأسرع والأذكى)',
                            'Claude 3.5 Sonnet',
                            'Gemini Pro 1.5',
                          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedModel = val);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader('اللغة والواجهة'),
                    _buildGlassCard(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          dropdownColor: const Color(0xFF0B0E1E),
                          style: const TextStyle(color: Colors.white),
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF00D2FF)),
                          items: ['العربية', 'English']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedLanguage = val);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader('حجم الخط في المحادثة'),
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('حجم الخط الحالي', style: TextStyle(color: Colors.white)),
                              Text(
                                '${_fontSize.toInt()}px',
                                style: const TextStyle(color: Color(0xFF00D2FF), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Slider(
                            value: _fontSize,
                            min: 12,
                            max: 22,
                            activeColor: const Color(0xFF00D2FF),
                            inactiveColor: Colors.white10,
                            onChanged: (val) => setState(() => _fontSize = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
