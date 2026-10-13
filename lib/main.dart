import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'قارئ سيريس',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  String _extractedText = "";
  String _fileName = "لم يتم اختيار ملف بعد";
  bool _isLoading = false;
  bool _isPlaying = false;
  String _currentLanguage = "ar-EG"; // الافتراضي عربي مصر (يمكن استخدام ar-SA)

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage(_currentLanguage);
    await _flutterTts.setSpeechRate(0.5); // سرعة القراءة
    await _flutterTts.setVolume(1.0);

    _flutterTts.setStartHandler(() => setState(() => _isPlaying = true));
    _flutterTts.setCompletionHandler(() => setState(() => _isPlaying = false));
    _flutterTts.setErrorHandler((msg) => setState(() => _isPlaying = false));
  }

  // دالة اختيار ملف PDF واستخراج النص منه دون إنترنت
  Future<void> _pickAndExtractPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
          _fileName = result.files.single.name;
        });

        File file = File(result.files.single.path!);
        final List<int> bytes = await file.readAsBytes();
        
        // استخدام Syncfusion PDF Document لمعالجة الملف محلياً
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        String text = PdfTextExtractor(document).extractText();
        document.dispose();

        setState(() {
          _extractedText = text.trim().isEmpty ? "تعذر استخراج نص أو الملف فارغ." : text;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _extractedText = "حدث خطأ أثناء قراءة الملف: $e";
      });
    }
  }

  // القراءة المباشرة
  Future<void> _speak() async {
    if (_extractedText.isNotEmpty) {
      await _flutterTts.setLanguage(_currentLanguage);
      await _flutterTts.speak(_extractedText);
    }
  }

  // إيقاف مؤقت
  Future<void> _pause() async {
    await _flutterTts.pause();
    setState(() => _isPlaying = false);
  }

  // إيقاف كلي
  Future<void> _stop() async {
    await _flutterTts.stop();
    setState(() => _isPlaying = false);
  }

  // حفظ الصوت كملف محلي (.wav أو .mp3 حسب نظام التشغيل) دون إنترنت
  Future<void> _saveAudio() async {
    if (_extractedText.isEmpty) return;

    // طلب صلاحيات التخزين
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        // لتوافقية أندرويد 13 فما فوق
        await Permission.manageExternalStorage.request();
      }
    }

    setState(() => _isLoading = true);
    try {
      Directory? downloadsDir = await getExternalStorageDirectory(); // أو getApplicationDocumentsDirectory()
      String textToSave = _extractedText.substring(0, _extractedText.length > 5000 ? 5000 : _extractedText.length); // تحديد طول النص للاستقرار أوفلاين
      
      String fileName = "audio_${DateTime.now().millisecondsSinceEpoch}.wav";
      
      // الدالة الأصلية في الحزمة لحفظ الصوت محلياً
      if (Platform.isAndroid) {
        await _flutterTts.synthesizeToFile(textToSave, fileName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("تم حفظ الملف بنجاح باسم: $fileName بمسار التطبيق الداخلي")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("فشل حفظ الملف: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تحويل PDF إلى صوت أوفلاين'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // قسم اختيار اللغة واختيار الملف
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                content: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("لغة القراءة:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        DropdownButton<String>(
                          value: _currentLanguage,
                          items: const [
                            DropdownMenuItem(value: "ar-EG", child: Text("العربية")),
                            DropdownMenuItem(value: "en-US", child: Text("English")),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _currentLanguage = value;
                                _flutterTts.setLanguage(_currentLanguage);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const Divider(),
                    Text(_fileName, style: const TextStyle(color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _pickAndExtractPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text("اختيار ملف PDF"),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            
            // لوحة التحكم بالصوت
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filled(
                  onPressed: _isPlaying ? _pause : _speak,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 32,
                ),
                IconButton.filled(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop),
                  iconSize: 32,
                  backgroundColor: Colors.red,
                ),
                IconButton.filled(
                  onPressed: _extractedText.isEmpty ? null : _saveAudio,
                  icon: const Icon(Icons.download),
                  iconSize: 32,
                  backgroundColor: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // عرض النص المستخرج
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _extractedText.isEmpty ? "سيتم عرض نص الملف هنا..." : _extractedText,
                          textDirection: _currentLanguage.startsWith('ar') ? TextDirection.rtl : TextDirection.ltr,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
