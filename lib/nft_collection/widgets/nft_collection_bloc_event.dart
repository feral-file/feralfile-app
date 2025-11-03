// // ignore_for_file: public_member_api_docs, sort_constructors_first
//
// import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
//
// enum NftLoadingState { notRequested, loading, error, done }
//
// abstract class NftCollectionBlocEvent {}
//
// class RefreshNftCollectionByOwners extends NftCollectionBlocEvent {
//   final List<String>? debugTokens;
//
//   RefreshNftCollectionByOwners({
//     this.debugTokens,
//   });
//
//   RefreshNftCollectionByOwners copyWith({
//     List<String>? debugTokens,
//   }) {
//     return RefreshNftCollectionByOwners(
//       debugTokens: debugTokens ?? this.debugTokens,
//     );
//   }
// }
//
// class RefreshNftCollectionByIDs extends NftCollectionBlocEvent {
//   final List<String>? ids;
//   final List<String>? debugTokenIds;
//   final bool shouldFetchIfNotExistsInCache;
//
//   RefreshNftCollectionByIDs(
//       {this.ids,
//       this.debugTokenIds,
//       this.shouldFetchIfNotExistsInCache = true});
// }
//
// class UpdateTokensEvent extends NftCollectionBlocEvent {
//   final NftLoadingState? state;
//   final List<AssetToken> tokens;
//
//   UpdateTokensEvent({this.state, this.tokens = const []});
// }
//
// class ReloadEvent extends NftCollectionBlocEvent {
//   ReloadEvent();
// }
//
// class GetTokensByOwnerEvent extends NftCollectionBlocEvent {
//   final PageKey pageKey;
//   final String? contractAddress;
//
//   GetTokensByOwnerEvent({required this.pageKey, this.contractAddress});
// }
//
// class GetTokensBeforeByOwnerEvent extends NftCollectionBlocEvent {
//   final PageKey? pageKey;
//   final List<String> owners;
//
//   GetTokensBeforeByOwnerEvent({this.pageKey, this.owners = const []});
// }
//
// class PageKey {
//   final int? offset;
//   final String id;
//   bool isLoaded;
//
//   PageKey({
//     required this.offset,
//     required this.id,
//     this.isLoaded = false,
//   });
//
//   factory PageKey.init() {
//     return PageKey(
//       id: '',
//       offset: null,
//     );
//   }
//
//   @override
//   bool operator ==(covariant PageKey other) {
//     if (identical(this, other)) return true;
//
//     return other.offset == offset &&
//         other.id == id &&
//         other.isLoaded == isLoaded;
//   }
//
//   @override
//   int get hashCode => offset.hashCode ^ id.hashCode ^ isLoaded.hashCode;
//
//   @override
//   String toString() => 'PageKey(offset: $offset, id: $id, isLoaded: $isLoaded)';
// }
//
// class RequestIndexEvent extends NftCollectionBlocEvent {
//   final List<String> addresses;
//
//   RequestIndexEvent(this.addresses);
// }
//
// class PurgeCache extends NftCollectionBlocEvent {}
