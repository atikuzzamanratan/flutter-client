import 'dart:io' as file;
import 'package:flutter_share/flutter_share.dart';
import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:invoiceninja_flutter/constants.dart';
import 'package:invoiceninja_flutter/data/models/company_model.dart';
import 'package:invoiceninja_flutter/redux/app/app_state.dart';
import 'package:invoiceninja_flutter/redux/reports/reports_actions.dart';
import 'package:invoiceninja_flutter/redux/reports/reports_state.dart';
import 'package:invoiceninja_flutter/redux/settings/settings_actions.dart';
import 'package:invoiceninja_flutter/ui/reports/client_report.dart';
import 'package:invoiceninja_flutter/ui/reports/reports_screen.dart';
import 'package:invoiceninja_flutter/utils/completers.dart';
import 'package:invoiceninja_flutter/utils/dialogs.dart';
import 'package:invoiceninja_flutter/utils/formatting.dart';
import 'package:invoiceninja_flutter/utils/localization.dart';
import 'package:memoize/memoize.dart';
import 'package:path_provider/path_provider.dart';
import 'package:redux/redux.dart';

import 'reports_screen.dart';

class ReportsScreenBuilder extends StatelessWidget {
  const ReportsScreenBuilder({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ReportsScreenVM>(
      converter: ReportsScreenVM.fromStore,
      builder: (context, vm) {
        return ReportsScreen(
          viewModel: vm,
        );
      },
    );
  }
}

class ReportsScreenVM {
  ReportsScreenVM({
    @required this.state,
    @required this.onSettingsChanged,
    @required this.onReportColumnsChanged,
    @required this.onReportFiltersChanged,
    @required this.onExportPressed,
    @required this.onReportSorted,
    @required this.reportTotals,
    @required this.reportResult,
  });

  final AppState state;
  final ReportResult reportResult;
  final Map<String, Map<String, double>> reportTotals;
  final Function(BuildContext, List<String>) onReportColumnsChanged;
  final Function(BuildContext) onExportPressed;
  final Function(BuildContext, BuiltMap<String, String>) onReportFiltersChanged;
  final Function(int, bool) onReportSorted;
  final Function({
    String report,
    String customStartDate,
    String customEndDate,
    String group,
    String subgroup,
    String chart,
  }) onSettingsChanged;

  static ReportsScreenVM fromStore(Store<AppState> store) {
    final state = store.state;
    final report = state.uiState.reportsUIState.report;
    ReportResult reportResult;

    switch (state.uiState.reportsUIState.report) {
      default:
        reportResult = memoizedClientReport(
          state.userCompany,
          state.uiState.reportsUIState,
          state.clientState.map,
          state.userState.map,
          state.staticState,
        );
        break;
    }

    print(
        '## TOTALS: ${memoizedReportTotals(reportResult, state.uiState.reportsUIState)}');

    return ReportsScreenVM(
        state: state,
        reportResult: reportResult,
        reportTotals:
            memoizedReportTotals(reportResult, state.uiState.reportsUIState),
        onReportSorted: (index, ascending) {
          store.dispatch(UpdateReportSettings(
            report: state.uiState.reportsUIState.report,
            sortIndex: index,
          ));
        },
        onReportFiltersChanged: (context, filterMap) {
          store.dispatch(UpdateReportSettings(
            report: report,
            filters: filterMap,
          ));
        },
        onReportColumnsChanged: (context, columns) {
          final allReportSettings = state.userCompany.settings.reportSettings;
          final reportSettings = (allReportSettings != null &&
                      allReportSettings.containsKey(report)
                  ? allReportSettings[report]
                  : ReportSettingsEntity())
              .rebuild((b) => b..columns.replace(BuiltList<String>(columns)));
          final user = state.user.rebuild((b) => b
            ..userCompany
                    .settings
                    .reportSettings[state.uiState.reportsUIState.report] =
                reportSettings);
          final completer = snackBarCompleter<Null>(
              context, AppLocalization.of(context).savedSettings);
          if (state.authState.hasRecentlyEnteredPassword) {
            store.dispatch(
              SaveUserSettingsRequest(
                completer: completer,
                user: user,
              ),
            );
          } else {
            passwordCallback(
                context: context,
                callback: (password) {
                  store.dispatch(
                    SaveUserSettingsRequest(
                      completer: completer,
                      user: user,
                      password: password,
                    ),
                  );
                });
          }
        },
        onSettingsChanged: ({
          String report,
          String group,
          String subgroup,
          String chart,
          String customStartDate,
          String customEndDate,
        }) {
          final reportState = state.uiState.reportsUIState;
          if (group != null && reportState.group != group) {
            store.dispatch(UpdateReportSettings(
              report: report ?? reportState.report,
              group: group,
              chart: chart,
              subgroup: subgroup,
              customStartDate: '',
              customEndDate: '',
              filters: BuiltMap<String, String>(),
            ));
          } else {
            store.dispatch(UpdateReportSettings(
              report: report ?? reportState.report,
              group: group,
              subgroup: subgroup,
              chart: chart,
              customStartDate: customStartDate,
              customEndDate: customEndDate,
            ));
          }
        },
        onExportPressed: (context) async {
          print('## EXPORT ##');
          String data = 'test_data';
          const filename = 'export.csv';

          if (kIsWeb) {
            /*
            final encodedFileContents = Uri.encodeComponent(data);
            AnchorElement(
                href: 'data:text/plain;charset=utf-8,$encodedFileContents')
              ..setAttribute('download', filename)
              ..click();
             */
          } else {
            final directory = await getExternalStorageDirectory();
            final filePath = '${directory.path}/$filename';
            final csvFile = file.File(filePath);
            csvFile.writeAsString(data);

            await FlutterShare.shareFile(
                title: 'Invoice Ninja',
                text: 'Example share text',
                filePath: filePath);
          }
        });
  }
}

var memoizedReportTotals = memo2((
  ReportResult reportResult,
  ReportsUIState reportUIState,
) =>
    calculateReportTotals(
        reportResult: reportResult, reportUIState: reportUIState));

Map<String, Map<String, double>> calculateReportTotals({
  ReportResult reportResult,
  ReportsUIState reportUIState,
}) {
  final Map<String, Map<String, double>> totals = {};
  final data = reportResult.data;
  final columns = reportResult.columns;

  if (reportUIState.group.isEmpty) {
    return totals;
  }

  for (var i = 0; i < data.length; i++) {
    final row = data[i];
    for (var j = 0; j < row.length; j++) {
      final cell = row[j];
      final column = columns[j];
      final columnIndex = columns.indexOf(reportUIState.group);

      dynamic group = row[columnIndex].value;

      if (getReportColumnType(reportUIState.group) ==
          ReportColumnType.dateTime) {
        group = convertDateTimeToSqlDate(DateTime.tryParse(group));
        if (reportUIState.subgroup == kReportGroupYear) {
          group = group.substring(0, 4) + '-01-01';
        } else if (reportUIState.subgroup == kReportGroupMonth) {
          group = group.substring(0, 7) + '-01';
        }
      }

      if (!totals.containsKey(group)) {
        totals['$group'] = {'count': 0};
      }
      if (column == reportUIState.group) {
        totals['$group']['count'] += 1;
      }
      if (cell is ReportNumberValue) {
        if (!totals['$group'].containsKey(column)) {
          totals['$group'][column] = 0;
        }
        totals['$group'][column] += cell.value;
      }
    }
  }

  return totals;
}
