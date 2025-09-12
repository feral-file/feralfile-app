import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/widgets/llm_text_input/llm_text_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage>
    with AutomaticKeepAliveClientMixin {
  late final UserAllOwnCollectionBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = injector<UserAllOwnCollectionBloc>();
    // For now, use example dynamic query from DP1Call.dynamicQuery
    // final sample = DP1Call(
    //   dpVersion: '1.0.0',
    //   id: 'sample',
    //   slug: 'sample',
    //   title: 'sample',
    //   created: DateTime.now(),
    //   defaults: const {},
    //   items: const [],
    //   signature: 'sample',
    // ).dynamicQuery;
    // _bloc.add(LoadDynamicQueryEvent(sample));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<UserAllOwnCollectionBloc, UserAllOwnCollectionState>(
      bloc: _bloc,
      builder: (context, state) {
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: LLMTextInput(
                active: true,
                placeholder: 'Type or Paste Address / Domain',
                onSend: (text) {
                  _bloc.add(InsertAddressEvent(text));
                },
              ),
            ),
            if (state.isLoading)
              SliverToBoxAdapter(child: const Center(child: LoadingWidget()))
            else if (state.isError)
              SliverToBoxAdapter(
                child: Center(
                  child: Text(
                    'Error: ${state.error}',
                    style: const TextStyle(color: AppColor.white),
                  ),
                ),
              )
            else
              UIHelper.assetTokenSliverGrid(
                  context, state.assetTokens, 'Collection'),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
