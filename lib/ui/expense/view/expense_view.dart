import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';
import 'package:invoiceninja_flutter/ui/app/buttons/bottom_buttons.dart';
import 'package:invoiceninja_flutter/ui/app/view_scaffold.dart';
import 'package:invoiceninja_flutter/ui/expense/view/expense_view_documents.dart';
import 'package:invoiceninja_flutter/ui/expense/view/expense_view_vm.dart';
import 'package:invoiceninja_flutter/ui/expense/view/expense_view_overview.dart';
import 'package:invoiceninja_flutter/utils/files.dart';
import 'package:invoiceninja_flutter/utils/localization.dart';
import 'package:permission_handler/permission_handler.dart';

class ExpenseView extends StatefulWidget {
  const ExpenseView({
    Key key,
    @required this.viewModel,
    @required this.isFilter,
  }) : super(key: key);

  final ExpenseViewVM viewModel;
  final bool isFilter;

  @override
  _ExpenseViewState createState() => _ExpenseViewState();
}

class _ExpenseViewState extends State<ExpenseView>
    with SingleTickerProviderStateMixin {
  TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(vsync: this, length: 2);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.of(context);
    final viewModel = widget.viewModel;
    final expense = viewModel.expense;

    return ViewScaffold(
      isFilter: widget.isFilter,
      entity: expense,
      appBarBottom: TabBar(
        controller: _controller,
        tabs: [
          Tab(
            text: localization.overview,
          ),
          Tab(
            text: expense.documents.isEmpty
                ? localization.documents
                : '${localization.documents} (${expense.documents.length})',
          ),
        ],
      ),
      body: Builder(builder: (context) {
        return Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: _controller,
                children: <Widget>[
                  RefreshIndicator(
                    onRefresh: () => viewModel.onRefreshed(context),
                    child: ExpenseOverview(
                      viewModel: viewModel,
                      isFilter: widget.isFilter,
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: () => viewModel.onRefreshed(context),
                    child: ExpenseViewDocuments(
                        viewModel: viewModel, expense: viewModel.expense),
                  ),
                ],
              ),
            ),
            BottomButtons(
              entity: expense,
              action1: EntityAction.clone,
              action2: expense.isInvoiced
                  ? EntityAction.archive
                  : EntityAction.newInvoice,
            )
          ],
        );
      }),
      floatingActionButton: viewModel.state.isEnterprisePlan
          ? Builder(builder: (BuildContext context) {
              return FloatingActionButton(
                heroTag: 'expense_fab',
                backgroundColor: Theme.of(context).primaryColorDark,
                onPressed: () async {
                  MultipartFile multipartFile;
                  if (kIsWeb) {
                    multipartFile = await pickFile();
                  } else {
                    final permissionStatus =
                        await [Permission.camera].request();
                    final permission = permissionStatus[Permission.camera] ??
                        PermissionStatus.undetermined;

                    if (permission == PermissionStatus.granted) {
                      final image = await ImagePicker()
                          .getImage(source: ImageSource.camera);
                      if (image != null && image.path != null) {
                        final bytes = await image.readAsBytes();
                        multipartFile = MultipartFile.fromBytes('file', bytes,
                            filename: image.path.split('/').last);
                      }
                    } else {
                      openAppSettings();
                    }
                  }
                  if (multipartFile != null) {
                    viewModel.onUploadDocument(context, multipartFile);
                  }
                },
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                ),
                tooltip: localization.create,
              );
            })
          : null,
    );
  }
}
