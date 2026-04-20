import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const QuickCalcApp());
}

// ─── App Root ────────────────────────────────────────────────────────────────
class QuickCalcApp extends StatelessWidget {
  const QuickCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickCalc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
      ),
      home: const CalculatorScreen(),
    );
  }
}

// ─── Colors ──────────────────────────────────────────────────────────────────
class AppColors {
  static const Color background  = Color(0xFF0D0D0F);
  static const Color surface     = Color(0xFF1A1A1F);
  static const Color surfaceHigh = Color(0xFF252530);
  static const Color accent      = Color(0xFFFF6B35);
  static const Color accentGlow  = Color(0x40FF6B35);
  static const Color accentSoft  = Color(0xFF2A1810);
  static const Color numBtn      = Color(0xFF1E1E26);
  static const Color opBtn       = Color(0xFF252535);
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textMuted   = Color(0xFF6B6B80);
  static const Color green       = Color(0xFF4ADE80);
  static const Color divider     = Color(0xFF2A2A35);
}

// ─── Calculator Logic ─────────────────────────────────────────────────────────
class CalculatorLogic extends ChangeNotifier {
  String _display      = '0';
  String _expression   = '';
  String _result       = '';
  double? _firstNum;
  String? _operator;
  bool _freshInput     = false;
  bool _justCalculated = false;

  String get display    => _display;
  String get expression => _expression;
  String get result     => _result;

  void input(String value) {
    HapticFeedback.lightImpact();

    switch (value) {
      case 'AC':  _clear();        break;
      case '⌫':   _backspace();    break;
      case '+/-': _toggleSign();   break;
      case '%':   _percent();      break;
      case '=':   _calculate();    break;
      case '.':   _addDecimal();   break;
      case '+':
      case '−':
      case '×':
      case '÷':   _setOperator(value); break;
      default:    _addDigit(value);    break;
    }
    notifyListeners();
  }

  void _clear() {
    _display      = '0';
    _expression   = '';
    _result       = '';
    _firstNum     = null;
    _operator     = null;
    _freshInput   = false;
    _justCalculated = false;
  }

  void _backspace() {
    // Error is not a substring edit; reset like after a completed calc.
    if (_display == 'Error') {
      _clear();
      return;
    }
    if (_justCalculated) { _clear(); return; }
    if (_display.length <= 1 || (_display.length == 2 && _display.startsWith('-'))) {
      _display = '0';
    } else {
      _display = _display.substring(0, _display.length - 1);
    }
  }

  void _toggleSign() {
    // Avoid mangling the literal "Error" string.
    if (_display == 'Error') return;
    if (_display == '0') return;
    _display = _display.startsWith('-')
        ? _display.substring(1)
        : '-$_display';
  }

  void _percent() {
    // Parse would treat Error as 0; ignore instead.
    if (_display == 'Error') return;
    final val = double.tryParse(_display) ?? 0;
    _display = _formatNum(val / 100);
    _justCalculated = false;
  }

  void _addDecimal() {
    // Digits replace Error via _addDigit; decimal needs the same guard.
    if (_display == 'Error') return;
    if (_freshInput || _justCalculated) {
      _display = '0.';
      _freshInput = false;
      _justCalculated = false;
      return;
    }
    if (!_display.contains('.')) _display += '.';
  }

  void _addDigit(String digit) {
    if (_justCalculated) {
      _display = digit;
      _justCalculated = false;
      _expression = '';
      _result = '';
      return;
    }
    if (_freshInput) {
      _display    = digit;
      _freshInput = false;
      return;
    }
    _display = (_display == '0') ? digit : _display + digit;
    // cap at 12 chars
    if (_display.replaceAll('-', '').replaceAll('.', '').length > 12) {
      _display = _display.substring(0, _display.length - 1);
    }
  }

  void _setOperator(String op) {
    // No numeric operand while showing Error (avoids null ! on parse).
    if (_display == 'Error') return;
    // chain operations
    if (_operator != null && !_freshInput) {
      _calculate(chaining: true);
      // Chained ÷0 leaves Error; do not overwrite with a new op.
      if (_display == 'Error') return;
    }
    // Safer than _firstNum!: non-numeric display skips quietly.
    final parsed = double.tryParse(_display);
    if (parsed == null) return;
    _firstNum   = parsed;
    _operator   = op;
    _expression = '${_formatNum(_firstNum!)} $op';
    _freshInput = true;
    _justCalculated = false;
  }

  // Dedicated reset so "Error" stays visible (_clear would show 0 again).
  void _divisionByZero() {
    _expression = '';
    _result = '';
    _firstNum = null;
    _operator = null;
    _freshInput = false;
    _justCalculated = true;
    _display = 'Error';
  }

  void _calculate({bool chaining = false}) {
    if (_operator == null || _firstNum == null) return;
    final second = double.tryParse(_display) ?? 0;
    double res;
    switch (_operator) {
      case '+': res = _firstNum! + second; break;
      case '−': res = _firstNum! - second; break;
      case '×': res = _firstNum! * second; break;
      case '÷':
        // Old code set Error then [_clear], which reset display to 0.
        if (second == 0) {
          _divisionByZero();
          return;
        }
        res = _firstNum! / second;
        break;
      default: return;
    }

    if (!chaining) {
      _expression     = '${_formatNum(_firstNum!)} $_operator ${_formatNum(second)} =';
      _result         = _formatNum(res);
      _display        = _formatNum(res);
      _operator       = null;
      _firstNum       = null;
      _justCalculated = true;
    } else {
      _firstNum = res;
      _display  = _formatNum(res);
    }
  }

  String _formatNum(double n) {
    if (n == n.truncateToDouble() && n.abs() < 1e12) {
      return n.toInt().toString();
    }
    // up to 8 decimal places, strip trailing zeros
    String s = n.toStringAsFixed(8);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return s;
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with TickerProviderStateMixin {
  final CalculatorLogic _logic = CalculatorLogic();
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  String _lastTapped = '';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 150));
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _logic.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _logic.dispose();
    super.dispose();
  }

  void _onButton(String val) {
    setState(() => _lastTapped = val);
    _pulseCtrl.forward().then((_) => _pulseCtrl.reverse());
    _logic.input(val);
  }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final isWide = size.width > 400;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────
            _buildHeader(),

            // ── Display ──────────────────────────────────────────────────
            Expanded(child: _buildDisplay()),

            // ── Divider ───────────────────────────────────────────────────
            Container(height: 1, color: AppColors.divider, margin:
                const EdgeInsets.symmetric(horizontal: 24)),

            const SizedBox(height: 20),

            // ── Buttons ───────────────────────────────────────────────────
            _buildButtonGrid(isWide),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('QuickCalc',
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 17, fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ]),
          // Mode label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: const Text('STANDARD',
                style: TextStyle(color: AppColors.accent, fontSize: 10,
                    fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          ),
        ],
      ),
    );
  }

  // ── Display ─────────────────────────────────────────────────────────────────
  Widget _buildDisplay() {
    final displayLen = _logic.display.length;
    double fontSize = displayLen <= 6 ? 72
        : displayLen <= 9  ? 56
        : displayLen <= 12 ? 44
        : 32;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Expression line
          AnimatedOpacity(
            opacity: _logic.expression.isNotEmpty ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              _logic.expression,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 18,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Main number
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: fontSize,
              fontWeight: FontWeight.w300,
              letterSpacing: -2,
              height: 1.1,
            ),
            child: Text(
              _logic.display,
              textAlign: TextAlign.right,
              maxLines: 1,
            ),
          ),

          const SizedBox(height: 6),

          // Result preview
          AnimatedOpacity(
            opacity: _logic.result.isNotEmpty ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(_logic.result,
                  style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  )),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Button Grid ──────────────────────────────────────────────────────────────
  Widget _buildButtonGrid(bool isWide) {
    const rows = [
      ['AC', '+/-', '%', '÷'],
      ['7',  '8',   '9', '×'],
      ['4',  '5',   '6', '−'],
      ['1',  '2',   '3', '+'],
      ['0',  '.',  '⌫',  '='],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: row.map((btn) {
                final isWideBtn = false; // No wide button in this layout
                return Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _CalcButton(
                      label    : btn,
                      onTap    : () => _onButton(btn),
                      type     : _buttonType(btn),
                      isActive : _logic.expression.contains(btn) &&
                                 _isOperator(btn),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  ButtonType _buttonType(String btn) {
    if (btn == '=') return ButtonType.equals;
    if (_isOperator(btn)) return ButtonType.operator;
    if (btn == 'AC' || btn == '+/-' || btn == '%') return ButtonType.function;
    return ButtonType.number;
  }

  bool _isOperator(String btn) =>
      btn == '+' || btn == '−' || btn == '×' || btn == '÷';
}

// ─── Button Types ─────────────────────────────────────────────────────────────
enum ButtonType { number, operator, function, equals }

// ─── Calc Button ──────────────────────────────────────────────────────────────
class _CalcButton extends StatefulWidget {
  final String     label;
  final VoidCallback onTap;
  final ButtonType type;
  final bool       isActive;

  const _CalcButton({
    required this.label,
    required this.onTap,
    required this.type,
    this.isActive = false,
  });

  @override
  State<_CalcButton> createState() => _CalcButtonState();
}

class _CalcButtonState extends State<_CalcButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scaleAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.91)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Color get _bgColor {
    if (widget.isActive) return AppColors.accent;
    switch (widget.type) {
      case ButtonType.equals:   return AppColors.accent;
      case ButtonType.operator: return AppColors.opBtn;
      case ButtonType.function: return AppColors.surfaceHigh;
      case ButtonType.number:   return AppColors.numBtn;
    }
  }

  Color get _fgColor {
    switch (widget.type) {
      case ButtonType.equals:   return Colors.white;
      case ButtonType.operator:
        return widget.isActive ? Colors.white : AppColors.accent;
      case ButtonType.function: return AppColors.textMuted;
      case ButtonType.number:   return AppColors.textPrimary;
    }
  }

  bool get _hasGlow =>
      widget.type == ButtonType.equals ||
      (widget.type == ButtonType.operator && widget.isActive);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { setState(() => _pressed = true);  _ctrl.forward(); },
      onTapUp:   (_) { setState(() => _pressed = false); _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () { setState(() => _pressed = false); _ctrl.reverse(); },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 72,
          decoration: BoxDecoration(
            color: _pressed ? _bgColor.withOpacity(0.85) : _bgColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: _hasGlow ? [
              BoxShadow(
                color: AppColors.accentGlow,
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: widget.type == ButtonType.operator ? Border.all(
              color: AppColors.accent.withOpacity(widget.isActive ? 0.8 : 0.25),
              width: 1,
            ) : null,
          ),
          child: Center(
            child: widget.label == '⌫'
                ? Icon(Icons.backspace_outlined, color: _fgColor, size: 22)
                : Text(
                    widget.label,
                    style: TextStyle(
                      color      : _fgColor,
                      fontSize   : _labelSize(),
                      fontWeight : _labelWeight(),
                      letterSpacing: widget.type == ButtonType.operator ? 0 : -0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  double _labelSize() {
    switch (widget.type) {
      case ButtonType.operator: return 28;
      case ButtonType.equals:   return 30;
      case ButtonType.function: return 18;
      case ButtonType.number:   return 26;
    }
  }

  FontWeight _labelWeight() {
    switch (widget.type) {
      case ButtonType.equals:   return FontWeight.w600;
      case ButtonType.operator: return FontWeight.w400;
      default: return FontWeight.w400;
    }
  }
}
