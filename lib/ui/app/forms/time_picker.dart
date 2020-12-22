import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:invoiceninja_flutter/redux/app/app_state.dart';
import 'package:invoiceninja_flutter/ui/app/forms/decorated_form_field.dart';
import 'package:invoiceninja_flutter/utils/formatting.dart';

class TimePicker extends StatefulWidget {
  const TimePicker({
    Key key,
    @required this.onSelected,
    @required this.selectedDateTime,
    @required this.selectedDate,
    this.isEndTime = false,
    this.labelText,
    this.validator,
    this.autoValidate = false,
    this.allowClearing = false,
  }) : super(key: key);

  final String labelText;
  final DateTime selectedDate;
  final DateTime selectedDateTime;
  final Function(DateTime) onSelected;
  final Function validator;
  final bool autoValidate;
  final bool allowClearing;
  final bool isEndTime;

  @override
  _TimePickerState createState() => new _TimePickerState();
}

class _TimePickerState extends State<TimePicker> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  String _pendingValue;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFoucsChanged);
  }

  @override
  void didChangeDependencies() {
    if (widget.selectedDateTime != null) {
      final formatted = formatDate(
          widget.selectedDateTime.toIso8601String(), context,
          showDate: false, showTime: true);

      _textController.text = formatted;
    }

    super.didChangeDependencies();
  }

  void _onFoucsChanged() {
    if (!_focusNode.hasFocus && widget.selectedDateTime != null) {
      _textController.text = formatDate(
          widget.selectedDateTime.toIso8601String(), context,
          showDate: false, showTime: true);

      setState(() {
        _pendingValue = null;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.removeListener(_onFoucsChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _showTimePicker() async {
    final selectedDateTime = widget.selectedDateTime?.toLocal();
    final now = DateTime.now();

    final hour = selectedDateTime?.hour ?? now.hour;
    final minute = selectedDateTime?.minute ?? now.minute;

    final TimeOfDay selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      //initialEntryMode: TimePickerEntryMode.input,
    );

    if (selectedTime != null) {
      var dateTime =
          convertTimeOfDayToDateTime(selectedTime, widget.selectedDate);

      if (widget.selectedDate != null &&
          dateTime.isBefore(widget.selectedDate)) {
        dateTime = dateTime.toUtc().add(Duration(days: 1)).toLocal();
      }

      _textController.text = formatDate(dateTime.toIso8601String(), context,
          showTime: true, showDate: false);

      widget.onSelected(dateTime.toLocal());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedFormField(
      focusNode: _focusNode,
      validator: widget.validator,
      controller: _textController,
      decoration: InputDecoration(
        labelText: _pendingValue ?? widget.labelText ?? '',
        suffixIcon: widget.allowClearing && widget.selectedDateTime != null
            ? IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  _textController.text = '';
                  widget.onSelected(null);
                },
              )
            : IconButton(
                icon: Icon(Icons.access_time),
                onPressed: () => _showTimePicker(),
              ),
      ),
      onChanged: (value) {
        if (value.isEmpty) {
          if (widget.allowClearing) {
            widget.onSelected(null);
          }
        } else {
          final initialValue = value;
          value = value.replaceAll(RegExp('[^\\d\:]'), '');
          value = value.toLowerCase().replaceAll('.', ':');

          final parts = value.split(':');
          String dateTimeStr = '';

          if (parts.length == 1) {
            dateTimeStr = parts[0] + ':00:00';
          } else {
            dateTimeStr = parts[0] + ':' + parts[1];
            if (parts[1].length == 1) {
              dateTimeStr += '0';
            }
            if (parts.length == 3) {
              dateTimeStr += ':' + parts[2];
            } else {
              dateTimeStr += ':00';
            }
          }

          if (initialValue.toLowerCase().contains('a')) {
            dateTimeStr += ' AM';
          } else if (initialValue.toLowerCase().contains('p')) {
            dateTimeStr += ' PM';
          } else {
            final store = StoreProvider.of<AppState>(context);
            if (!store.state.company.settings.enableMilitaryTime) {
              final hour = parseDouble(parts[0]);
              dateTimeStr += hour > 6 ? ' AM' : ' PM';
            }
          }

          final dateTime = parseTime(dateTimeStr, context);

          if (dateTime != null) {
            final date = widget.selectedDate?.toLocal() ?? DateTime.now();
            var selectedDate = DateTime(
              date.year,
              date.month,
              date.day,
              dateTime.hour,
              dateTime.minute,
              dateTime.second,
            ).toUtc();

            if (selectedDate.isBefore(date) && widget.isEndTime) {
              selectedDate =
                  selectedDate.toUtc().add(Duration(days: 1)).toLocal();
            }

            widget.onSelected(selectedDate);

            setState(() {
              _pendingValue = formatDate(
                  selectedDate.toIso8601String(), context,
                  showTime: true, showDate: false);
            });
          }
        }
      },
    );
  }
}
