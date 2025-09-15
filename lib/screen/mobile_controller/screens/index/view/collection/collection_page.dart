import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/view_existing_address_bloc.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/view_existing_address_state.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/widgets/ff_text_field/ff_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage>
    with AutomaticKeepAliveClientMixin {
  late final UserAllOwnCollectionBloc _collectionBloc;
  late final ViewExistingAddressBloc _addressBloc;

  @override
  void initState() {
    super.initState();
    _collectionBloc = injector<UserAllOwnCollectionBloc>();
    _addressBloc = ViewExistingAddressBloc(injector(), injector());
  }

  @override
  void dispose() {
    _collectionBloc.close();
    _addressBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Builder(
      builder: (context) {
        return CustomScrollView(
          shrinkWrap: true,
          slivers: [
            BlocBuilder<ViewExistingAddressBloc, ViewExistingAddressState>(
              bloc: _addressBloc,
              builder: (context, addressState) {
                return SliverToBoxAdapter(
                  child: FFTextField(
                    active: true,
                    placeholder: 'Type or Paste Address / Domain',
                    isError: addressState.isError,
                    isLoading: addressState.isAddConnectionLoading,
                    errorMessage: addressState.exception?.message ??
                        (addressState.isError ? 'Invalid address' : null),
                    onChanged: (text) {
                      _addressBloc.add(AddressChangeEvent(text));
                    },
                    onSend: (text) {
                      _addressBloc.add(AddConnectionEvent());
                    },
                  ),
                );
              },
            ),
            // Collection content with UserAllOwnCollectionBloc
            BlocBuilder<UserAllOwnCollectionBloc, UserAllOwnCollectionState>(
              bloc: _collectionBloc,
              builder: (context, collectionState) {
                if (collectionState.isLoading)
                  return SliverToBoxAdapter(
                      child: const Center(child: LoadingWidget()));
                else if (collectionState.isError)
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        'Error: ${collectionState.error}',
                        style: const TextStyle(color: AppColor.white),
                      ),
                    ),
                  );
                else
                  return UIHelper.assetTokenSliverGrid(
                      context, collectionState.assetTokens, 'Collection');
              },
            ),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
