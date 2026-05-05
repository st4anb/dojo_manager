import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class AppFormatters {
  static MaskTextInputFormatter get cpfMask => MaskTextInputFormatter(
    mask: '###.###.###-##', 
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  static MaskTextInputFormatter get rgMask => MaskTextInputFormatter(
    mask: '##.###.###-#', 
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  static MaskTextInputFormatter get phoneMask => MaskTextInputFormatter(
    mask: '(##) #####-####', 
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  
  static MaskTextInputFormatter get dateMask => MaskTextInputFormatter(
    mask: '##/##/####', 
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  static MaskTextInputFormatter get cepMask => MaskTextInputFormatter(
    mask: '#####-###', 
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
}
