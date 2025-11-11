import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:sentry/sentry.dart';

class IndexerClient {
  IndexerClient(
    this._baseUrl, {
    AuthService? authService,
    Future<String> Function()? getTokenOverride,
  })  : _authService = authService,
        _getTokenOverride = getTokenOverride;

  final String _baseUrl;
  final AuthService? _authService;
  final Future<String> Function()? _getTokenOverride;

  GraphQLClient get client {
    final httpLink = HttpLink(
      '$_baseUrl/graphql',
      httpClient: _TimeoutHttpClient(
        http.Client(),
        const Duration(seconds: 30),
      ),
    );
    // Default client without auth; use _createAuthenticatedClient() when JWT is required
    final link = httpLink;

    return GraphQLClient(
      cache: GraphQLCache(dataIdFromObject: (data) => null),
      link: link,
    );
  }

  Future<dynamic> query({
    required String doc,
    Map<String, dynamic> vars = const {},
    bool withToken = false,
    String? subKey,
  }) async {
    try {
      final options = QueryOptions(
        document: gql(doc),
        variables: vars,
        // Avoid short implicit timeouts by keeping logic in links; allow cache if needed
        // fetchPolicy: FetchPolicy.networkOnly,
      );

      final result = await client.query(options);
      if (result.hasException) {
        NftCollection.logger
            .info('Error when querying: $doc with params: $vars');
        NftCollection.logger.warning(
          'GraphQL query exception: link: ${result.exception?.linkException}; graphql: ${result.exception?.graphqlErrors.map((e) => e.message).join(', ')}',
        );
        Sentry.captureEvent(SentryEvent(
          message: SentryMessage(
            'GraphQL query exception: link: ${result.exception?.linkException}; graphql: ${result.exception?.graphqlErrors.map((e) => e.message).join(', ')}',
          ),
          level: SentryLevel.error,
          tags: {
            'doc': doc,
            'vars': vars.toString(),
          },
          throwable: result.exception,
        ));
      }
      if (subKey != null) {
        return result.data?[subKey];
      }
      return result.data;
    } catch (e) {
      NftCollection.logger.info('Error querying: $e');
      return null;
    }
  }

  Future<dynamic> mutate({
    required String doc,
    Map<String, dynamic> vars = const {},
    bool withToken = false,
  }) async {
    try {
      // Create a new client with auth if token is needed
      final clientToUse = withToken ? _createAuthenticatedClient() : client;

      final options = MutationOptions(
        document: gql(doc),
        variables: vars,
      );
      final result = await clientToUse.mutate(options);
      if (result.exception != null) {
        NftCollection.logger.info('Error mutating: $doc with params: $vars');
        Sentry.captureEvent(SentryEvent(
          message: SentryMessage(
            'GraphQL mutation exception: link: ${result.exception?.linkException}; graphql: ${result.exception?.graphqlErrors.map((e) => e.message).join(', ')}',
          ),
          level: SentryLevel.error,
          tags: {
            'doc': doc,
            'vars': vars.toString(),
          },
          throwable: result.exception,
        ));
        throw result.exception!;
      }
      return result.data;
    } catch (e) {
      NftCollection.logger.info('Error mutating: $e');
      rethrow;
    }
  }

  GraphQLClient _createAuthenticatedClient() {
    final httpLink = HttpLink(
      '$_baseUrl/graphql',
      httpClient: _TimeoutHttpClient(
        http.Client(),
        const Duration(seconds: 30),
      ),
    );
    final authLink = AuthLink(getToken: _getToken);
    final link = authLink.concat(httpLink);

    return GraphQLClient(
      cache: GraphQLCache(dataIdFromObject: (data) => null),
      link: link,
    );
  }

  Future<String> _getToken() async {
    try {
      if (_getTokenOverride != null) {
        final authToken = await _getTokenOverride();
        NftCollection.logger
            .info('IndexerClient: getToken ${authToken.substring(0, 10)}');
        return authToken;
      }
      if (_authService == null) return '';
      final jwt = await _authService.getAuthToken();
      NftCollection.logger
          .info('IndexerClient: getToken ${jwt?.jwtToken.substring(0, 10)}');
      return jwt != null ? 'Bearer ${jwt.jwtToken}' : '';
    } catch (e) {
      NftCollection.logger.warning('Failed to get auth token: $e');
      return '';
    }
  }
}

class _TimeoutHttpClient extends http.BaseClient {
  _TimeoutHttpClient(this._inner, this.timeout);

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(timeout);
  }

  @override
  void close() {
    _inner.close();
  }
}

final mockdata = {
  "tokens": {
    "items": [
      // {
      //   "id": "1",
      //   "chain": "eip155:1",
      //   "contract_address": "0x0000f6bc84ab98fbd8fce1f6d047965c723f0000",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0x0000f6bc84ab98fbd8fce1f6d047965c723f0000:1",
      //   "token_number": "1",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T07:28:57.237139Z",
      //   "metadata": {
      //     "name": "Into the Light #1",
      //     "description":
      //         "An ever-expanding array of lights spreads though space, illuminating the void with a meditative atmosphere of color.",
      //     "image_url":
      //         "https://media-proxy.artblocks.io/0x0000f6bc84ab98fbd8fce1f6d047965c723f0000/1.png",
      //     "animation_url":
      //         "https://generator.artblocks.io/0x0000f6bc84ab98fbd8fce1f6d047965c723f0000/1",
      //     "mime_type": "text/html; charset=utf-8",
      //     "artists": [
      //       {"name": "Jason Ting", "did": ""}
      //     ],
      //     "publisher": {"name": "Art Blocks", "url": "https://artblocks.io"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0x4763fd6c3a0aafa4aec7dc032c2769cf9b20655fc2a0bbe63c70424533f94930",
      //         "timestamp": "2025-10-28T04:17:11Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": {
      //     "name": "Into the Light #1",
      //     "description":
      //         "An ever-expanding array of lights spreads though space, illuminating the void with a meditative atmosphere of color.",
      //     "image_url":
      //         "https://media-proxy.artblocks.io/0x0000f6bc84ab98fbd8fce1f6d047965c723f0000/1.png",
      //     "animation_url":
      //         "https://generator.artblocks.io/0x0000f6bc84ab98fbd8fce1f6d047965c723f0000/1",
      //     "mime_type": "text/html; charset=utf-8",
      //     "artists": [
      //       {
      //         "name": "Jason Ting",
      //         "did":
      //             "did:pkh:eip155:1:0x87f669c0ee22c42be261dd74143e716748ba11ba"
      //       }
      //     ]
      //   },
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://media-proxy.artblocks.io/0x0000f6bc84ab98fbd8fce1f6d047965c723f0000/1.png",
      //       "mime_type": "image/png",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1966bb90-8264-44c8-e0b9-fb731d5c8100/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1966bb90-8264-44c8-e0b9-fb731d5c8100/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1966bb90-8264-44c8-e0b9-fb731d5c8100/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1966bb90-8264-44c8-e0b9-fb731d5c8100/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1966bb90-8264-44c8-e0b9-fb731d5c8100/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1966bb90-8264-44c8-e0b9-fb731d5c8100/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1966bb90-8264-44c8-e0b9-fb731d5c8100/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1966bb90-8264-44c8-e0b9-fb731d5c8100/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1966bb90-8264-44c8-e0b9-fb731d5c8100/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1966bb90-8264-44c8-e0b9-fb731d5c8100/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1966bb90-8264-44c8-e0b9-fb731d5c8100/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1966bb90-8264-44c8-e0b9-fb731d5c8100/thumbnailList"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "4",
      //   "chain": "eip155:1",
      //   "contract_address": "0xD8eed224E1B358fa6f7b167124C2c1AFe42275b4",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0xD8eed224E1B358fa6f7b167124C2c1AFe42275b4:84663873992476681896122431947515231738045062356454585024952296645344409704130",
      //   "token_number":
      //       "84663873992476681896122431947515231738045062356454585024952296645344409704130",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:12.468142Z",
      //   "metadata": {
      //     "name": "Entity #94",
      //     "description":
      //         "“Entity” is a wonderful dance of life. Colorful microorganisms are born, engage in naturalistic individual and group behaviors, evolve, and then terminate, making room for new specimens to emerge. The balletic choreography is governed not by linear animation but through the artist’s deep exploration and understanding of force-repulsion fields. Indeed, work with this complexity and nuance would seem impossible to animate by hand and feels closer to systems and behaviors we are accustomed to seeing only in nature. Such is the unique brilliance of Jared S Tarbell that his work does not capture nature, it rivals it. \n\nThis work is a programmed system and the video artifact was a capture of live interaction by the artist. The collectors will receive the interactive software as part of the acquisition. The music in this piece is “Infinity Machine” by Tonepoet.",
      //     "image_url":
      //         "https://imagedelivery.net/5BJzhBHeVhlhbn58hvcXAQ/6bb0b173-bf85-4f02-e06b-076b795a2200/thumbnailLarge",
      //     "animation_url":
      //         "https://cdn.feralfileassets.com/previews/0698273e-13fc-43e9-910e-0f6d81827a01/1641571880/preview.mp4",
      //     "mime_type": "video/mp4",
      //     "artists": [
      //       {"name": "Jared S Tarbell", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x23324ed44904260fE555B18E5Ba95C6030B9227d",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0xb4901cc58a5d55def03a492db3583dd8e085a5daa562bd5c18b13ee5ae01c507",
      //         "timestamp": "2025-07-07T02:11:23Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x17fFe0B00ff5194827b69E469BD938be59c1B10c",
      //         "to_address": "0x23324ed44904260fE555B18E5Ba95C6030B9227d",
      //         "tx_hash":
      //             "0x58450ac77e865eea8c5c9faa50a94f157afeb702bce3a9d6487f7a1eb5e21482",
      //         "timestamp": "2025-05-04T20:13:59Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0x17fFe0B00ff5194827b69E469BD938be59c1B10c",
      //         "tx_hash":
      //             "0x6a36880c7a23e69dad598714737f22a1474a7d4d8440750f33eb4e48ebf8d459",
      //         "timestamp": "2022-11-01T11:30:35Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://imagedelivery.net/5BJzhBHeVhlhbn58hvcXAQ/6bb0b173-bf85-4f02-e06b-076b795a2200/thumbnailLarge",
      //       "mime_type": "image/png",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/a903fa5a-8d49-411c-51af-518357265500/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/a903fa5a-8d49-411c-51af-518357265500/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/a903fa5a-8d49-411c-51af-518357265500/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/a903fa5a-8d49-411c-51af-518357265500/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/a903fa5a-8d49-411c-51af-518357265500/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/a903fa5a-8d49-411c-51af-518357265500/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/a903fa5a-8d49-411c-51af-518357265500/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/a903fa5a-8d49-411c-51af-518357265500/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/a903fa5a-8d49-411c-51af-518357265500/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/a903fa5a-8d49-411c-51af-518357265500/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/a903fa5a-8d49-411c-51af-518357265500/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/a903fa5a-8d49-411c-51af-518357265500/thumbnailList"
      //       }
      //     },
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/previews/0698273e-13fc-43e9-910e-0f6d81827a01/1641571880/preview.mp4",
      //       "mime_type": "video/mp4",
      //       "variant_urls": {
      //         "hls":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/995c46aef12c6b649e10e40f82a9889d/manifest/video.m3u8",
      //         "dash":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/995c46aef12c6b649e10e40f82a9889d/manifest/video.mpd",
      //         "preview":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/995c46aef12c6b649e10e40f82a9889d/watch",
      //         "thumbnail":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/995c46aef12c6b649e10e40f82a9889d/thumbnails/thumbnail.jpg"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "5",
      //   "chain": "eip155:1",
      //   "contract_address": "0xE5163c74fFE6563D75d750E5d767122500a1c337",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0xE5163c74fFE6563D75d750E5d767122500a1c337:43792463560781556265569689858463143429649243267448038556726932312834463981170",
      //   "token_number":
      //       "43792463560781556265569689858463143429649243267448038556726932312834463981170",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:12.389443Z",
      //   "metadata": {
      //     "name": "k.a9 #11",
      //     "description":
      //         "In the long tradition of kinetic art and experimental film and video, p1xelfool&rsquo;s works contain a world within themselves. We might be looking at the inside of an atom or the birth of a simulated universe &mdash; the work leaves room for broad interpretation. There&rsquo;s enough within them to trigger recognition and association, but the lack of resolution creates space for mystery. In &ldquo;k.a9&rdquo; specifically, we experience two objects rotating around one another in an endless dance of forces in balance. This software is one of a pair of p1xelfool&rsquo;s first ever generative, live-code releases. We&rsquo;re thrilled to feature this new direction on Feral File.",
      //     "image_url":
      //         "https://ipfs.io/ipfs/QmTeaSeVGAuZKypXYfaT7RceXCdBSL4AGjnsz2o7WnnoKh",
      //     "animation_url":
      //         "https://ipfs.io/ipfs/QmSVuBzn8R12RWrvkR7bLExx4CED6W4BZ1Kg7sVZZvT7BR?edition_number=11&blockchain=bitmark",
      //     "mime_type": "text/html; charset=utf-8",
      //     "artists": [
      //       {"name": "p1xelfool", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0xdae43dc5995B923Fe10E634Fe7F167191960890D",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0x0f2d301a1c3cf6c8d53b773c9f51fc2424306823601906c78fabac552e4f10ca",
      //         "timestamp": "2025-02-26T16:17:59Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0xdae43dc5995B923Fe10E634Fe7F167191960890D",
      //         "tx_hash":
      //             "0x8e39d476f018bffffb259cf77ab604a2288cc93414cee98682423480b04cb896",
      //         "timestamp": "2023-04-08T10:23:47Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://ipfs.io/ipfs/QmTeaSeVGAuZKypXYfaT7RceXCdBSL4AGjnsz2o7WnnoKh",
      //       "mime_type": "image/jpeg",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/f8b90b1b-7c3f-45cd-be82-f5db0571a200/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/f8b90b1b-7c3f-45cd-be82-f5db0571a200/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/f8b90b1b-7c3f-45cd-be82-f5db0571a200/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/f8b90b1b-7c3f-45cd-be82-f5db0571a200/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/f8b90b1b-7c3f-45cd-be82-f5db0571a200/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/f8b90b1b-7c3f-45cd-be82-f5db0571a200/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/f8b90b1b-7c3f-45cd-be82-f5db0571a200/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/f8b90b1b-7c3f-45cd-be82-f5db0571a200/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/f8b90b1b-7c3f-45cd-be82-f5db0571a200/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/f8b90b1b-7c3f-45cd-be82-f5db0571a200/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/f8b90b1b-7c3f-45cd-be82-f5db0571a200/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/f8b90b1b-7c3f-45cd-be82-f5db0571a200/thumbnailList"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "6",
      //   "chain": "eip155:1",
      //   "contract_address": "0xF51bFC40C10289246e5BBa7afEDeB8cF976c3250",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0xF51bFC40C10289246e5BBa7afEDeB8cF976c3250:252847730990432231993769525594770180945166981",
      //   "token_number": "252847730990432231993769525594770180945166981",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:12.571116Z",
      //   "metadata": {
      //     "name": "Superbloom #70",
      //     "description":
      //         "“Superbloom\" by Elsif captures the ephemeral floral beauty of spring on the Pacific Coast. An experiment in creating 144 individual artworks that connect together, with each piece flowing seamlessly into the next, inviting you on an endless walk through a meadow by the sea. \n\nMemory’s nostalgia is presented as the peaceful calm of an ocean breeze flows over the flowers and grass. The art style transitions between clear geometric shapes and loose painterly strokes, which heightens the appreciation of the knowledge that “Superbloom\" is created with code rather than a paintbrush. The influence of traditional Chinese art shines through in the continuous landscape, the elegant movement of calligraphic brushes echoing in the implied movement across the horizon.\n\nElsif worked directly with the themes of the exhibition, choosing to create a continuous piece that pulls at the threads of connection and the fluid exchange of ideas.\n\nInteractive keyboard controls:\n[f] Fill the current window (press ‘f’ again to get back to the original aspect ratio).\n[g] Toggle the background texture.\n[m] Change the margin amount.\n[s] Save a PNG image of the live view, default resolution is 1500 × 2000 pixels.\n[j] Save a JPEG image of the live view, default resolution is 1500 × 2000 pixels.\n[1]-[3] Change the output resolution, up to 4500 × 6000 pixels.\n\nURL parameters:\n&aspect=[an aspect ratio between 0.25 and 4, default is 0.75]\n&texture=[a roughness value greater than or equal to 0, default is 0.8]\n&margin=[the amount of margin around the painting (try 20 to 150), default is 20]\n&fill=[true/false, whether to fill the window]\n",
      //     "image_url":
      //         "https://ipfs.io/ipfs/QmREUg8U64Y7mqZyeWebGT6MKHbBQkpN1hVXyJXjcyLWat",
      //     "animation_url":
      //         "https://ipfs.io/ipfs/QmTCn4qjkdw6Z8UK4P5PE8dGnLTX9E3jwXvdGcPREoFhkP?edition_number=69&blockchain=ethereum&contract=0xF51bFC40C10289246e5BBa7afEDeB8cF976c3250&token_id=252847730990432231993769525594770180945166981&token_id_hash=0x04f78a38ac1460d5ceceb885962397d3bf1c8f7e28ea0de6eab7ab162ff49920",
      //     "mime_type": "text/html; charset=utf-8",
      //     "artists": [
      //       {"name": "Elsif", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0xE8C44C30E8E52c38Ac7bD232e7B7F0c7463A5351",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0x20b6047af5f627c906a47a57b570e96afb131977f05fc8fd2aad09237c7476cd",
      //         "timestamp": "2024-10-24T00:37:23Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0xF51bFC40C10289246e5BBa7afEDeB8cF976c3250",
      //         "to_address": "0xE8C44C30E8E52c38Ac7bD232e7B7F0c7463A5351",
      //         "tx_hash":
      //             "0xa1597aef2dcaa4dc1853c27220ad7f5ac9a962548ff6aba854b49bb216fc3eb9",
      //         "timestamp": "2024-10-22T04:03:11Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0xF51bFC40C10289246e5BBa7afEDeB8cF976c3250",
      //         "tx_hash":
      //             "0xe9d99acb3bd21690471affb7fad4c7f4bcf24a7c1e3f11f8fa2a215eba362e22",
      //         "timestamp": "2023-07-20T12:19:59Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "7",
      //   "chain": "eip155:1",
      //   "contract_address": "0x28b51BA8B990c48CB22cB6EF0ad5415fdBA5210C",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0x28b51BA8B990c48CB22cB6EF0ad5415fdBA5210C:56106112984270038917905828064139003773693484334495013411603562382354856816847",
      //   "token_number":
      //       "56106112984270038917905828064139003773693484334495013411603562382354856816847",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:12.311642Z",
      //   "metadata": {
      //     "name": "1DE94 #19",
      //     "description":
      //         "Raven Kwok&rsquo;s work is always inventive and meticulous, and &ldquo;IDE94,&rdquo; his piece in Social Codes, is no different. &ldquo;IDE94&rdquo; is a generative visual artwork based on a two&#45;dimensional tree map structure. Its random yet organic visual texture and motion pattern are created by controlling nodes on every recursion level of the tree structure, and by assigning a position for each node, Kwok dynamically changes the density and pattern of the consecutive line segments within the finite space. &ldquo;IDE94&rdquo; is a semi&#45;automatic artwork; it constantly changes its own geometry, but at any moment the viewer can pull and stretch it apart, only to watch it return to its starting point, step by step.",
      //     "image_url":
      //         "https://ipfs.io/ipfs/QmXrYJe5R18nQ5UWwpYw3zd4mwmJSWXhFBUc7hfXkAaebc",
      //     "animation_url":
      //         "https://ipfs.io/ipfs/QmRpqNbJDvf6fDfum4xLQNFJVrgU38tMECkT8JjizcBKUt?edition_number=19&blockchain=bitmark",
      //     "mime_type": "text/html; charset=utf-8",
      //     "artists": [
      //       {"name": "Raven Kwok", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x0D2c20d369c745B5e5DA72BC1921fA4e59F7F6e3",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0xe3763ae177fe414604ec1174bf07c1752221d31decd4e2e6df7da1a789d79a60",
      //         "timestamp": "2024-07-26T16:06:35Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0x0D2c20d369c745B5e5DA72BC1921fA4e59F7F6e3",
      //         "tx_hash":
      //             "0x59a4a01d1320c5944368097149cecd50159a4c6635c385f7a0e40fb8dee0919e",
      //         "timestamp": "2024-01-11T22:49:23Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://ipfs.io/ipfs/QmXrYJe5R18nQ5UWwpYw3zd4mwmJSWXhFBUc7hfXkAaebc",
      //       "mime_type": "image/jpeg",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dbe6b8ee-6157-4feb-ae8b-694634a91500/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dbe6b8ee-6157-4feb-ae8b-694634a91500/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dbe6b8ee-6157-4feb-ae8b-694634a91500/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dbe6b8ee-6157-4feb-ae8b-694634a91500/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dbe6b8ee-6157-4feb-ae8b-694634a91500/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dbe6b8ee-6157-4feb-ae8b-694634a91500/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dbe6b8ee-6157-4feb-ae8b-694634a91500/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dbe6b8ee-6157-4feb-ae8b-694634a91500/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dbe6b8ee-6157-4feb-ae8b-694634a91500/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dbe6b8ee-6157-4feb-ae8b-694634a91500/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dbe6b8ee-6157-4feb-ae8b-694634a91500/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dbe6b8ee-6157-4feb-ae8b-694634a91500/thumbnailList"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "13",
      //   "chain": "eip155:1",
      //   "contract_address": "0x28b51BA8B990c48CB22cB6EF0ad5415fdBA5210C",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0x28b51BA8B990c48CB22cB6EF0ad5415fdBA5210C:82162346596283144564966583883145667011953207418372457382158238642223100810996",
      //   "token_number":
      //       "82162346596283144564966583883145667011953207418372457382158238642223100810996",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:12.906654Z",
      //   "metadata": {
      //     "name": "Lamia #70",
      //     "description":
      //         "Frederik Vanhoutte has pushed his work into a new direction with &ldquo;Lamia,&rdquo; an isometric presentation of the poem with the same name written by John Keats in 1819. The work cycles through the 728 lines of the poem, with one line presented every 8 seconds, so it takes 97 minutes for the entire text to cycle back to the start. The selected 3 &times; 3 pixel font intentionally obscures the text, but with practice, it can indeed be read. Frederik is interested in two interpretations of the poem: first, as a way to express the idea that scientific knowledge doesn&rsquo;t destroy the romantic idea of beauty; and second, as a cautionary tale of misguided cultural subversion.",
      //     "image_url":
      //         "https://cdn.feralfileassets.com/thumbnails/33e55482-5dac-40b8-972e-750c374d69bb/1615540634",
      //     "animation_url":
      //         "https://cdn.feralfileassets.com/previews/33e55482-5dac-40b8-972e-750c374d69bb/1615652677/index.html",
      //     "mime_type": "text/html; charset=utf-8",
      //     "artists": [
      //       {"name": "Frederik Vanhoutte", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0xD9Ba9Efc69BDBAb198587f91B412Ae2c83298ef0",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0xf42bab9810952f15cc553a0d86666c862f9df23122d53f98ff0e6c704809f6e9",
      //         "timestamp": "2024-03-29T10:54:23Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0xD9Ba9Efc69BDBAb198587f91B412Ae2c83298ef0",
      //         "tx_hash":
      //             "0x7ff4b183bb67b5a8229a2a03f9c3d667842e542e2148bf80a4d1b49313099592",
      //         "timestamp": "2022-09-28T13:51:11Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/thumbnails/33e55482-5dac-40b8-972e-750c374d69bb/1615540634",
      //       "mime_type": "image/jpeg",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/771b4869-0b9d-47fc-4b2b-4b9a78c93b00/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/771b4869-0b9d-47fc-4b2b-4b9a78c93b00/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/771b4869-0b9d-47fc-4b2b-4b9a78c93b00/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/771b4869-0b9d-47fc-4b2b-4b9a78c93b00/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/771b4869-0b9d-47fc-4b2b-4b9a78c93b00/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/771b4869-0b9d-47fc-4b2b-4b9a78c93b00/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/771b4869-0b9d-47fc-4b2b-4b9a78c93b00/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/771b4869-0b9d-47fc-4b2b-4b9a78c93b00/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/771b4869-0b9d-47fc-4b2b-4b9a78c93b00/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/771b4869-0b9d-47fc-4b2b-4b9a78c93b00/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/771b4869-0b9d-47fc-4b2b-4b9a78c93b00/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/771b4869-0b9d-47fc-4b2b-4b9a78c93b00/thumbnailList"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "8",
      //   "chain": "eip155:1",
      //   "contract_address": "0xE5163c74fFE6563D75d750E5d767122500a1c337",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0xE5163c74fFE6563D75d750E5d767122500a1c337:109306892524557668562611376466566141821456642481863638052963541895447922445972",
      //   "token_number":
      //       "109306892524557668562611376466566141821456642481863638052963541895447922445972",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:12.587644Z",
      //   "metadata": {
      //     "name": "Picnic 001 #30",
      //     "description":
      //         "In describing her &ldquo;Picnic 001,&rdquo; Raquel Meyers writes, &ldquo;We keep going backwards no matter what,&rdquo; and she calls it a &ldquo;decoration for high-resolution screens. A roadside picnic for civil care.&rdquo; Raquel lives in the Basque Country in Spain, and within this artwork she brings together the industrial heritage of that area, the new dress code for women in Afghanistan, and the mediation of the smartphone. Raquel created the frames of this GIF animation with techniques she developed over years of engaging with vintage computer technologies, specifically Teletext systems and Commodore 64 computers.",
      //     "image_url":
      //         "https://cdn.feralfileassets.com/thumbnails/f548cb77-a829-42ea-b097-3b54603a0d8f/1631287470",
      //     "animation_url":
      //         "https://cdn.feralfileassets.com/previews/f548cb77-a829-42ea-b097-3b54603a0d8f/1631287550/preview.gif",
      //     "mime_type": "image/gif",
      //     "artists": [
      //       {"name": "Raquel Meyers", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x56003bbe847C587cF25E64cD92B913678d0d5536",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0x8507b0677f3a9fa45af9d3d47a21fe32bd1559b9b4aa2419cc00fa40e886f192",
      //         "timestamp": "2024-03-24T04:29:11Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x36de990133D36d7E3DF9a820aA3eDE5a2320De71",
      //         "to_address": "0x56003bbe847C587cF25E64cD92B913678d0d5536",
      //         "tx_hash":
      //             "0x039a5ed865f3ebe72cb18d8e1c1af58002c70371d383d1ee7f44c023207a83a9",
      //         "timestamp": "2022-12-15T18:37:59Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0x36de990133D36d7E3DF9a820aA3eDE5a2320De71",
      //         "tx_hash":
      //             "0x763747f2b4e0fe06141052cb092afa53dc7cbd06370a98de316a509b04d2b613",
      //         "timestamp": "2022-01-30T12:19:15Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/thumbnails/f548cb77-a829-42ea-b097-3b54603a0d8f/1631287470",
      //       "mime_type": "image/png",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dc14d0b5-e019-470e-a17e-bc65a3ef0500/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dc14d0b5-e019-470e-a17e-bc65a3ef0500/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dc14d0b5-e019-470e-a17e-bc65a3ef0500/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dc14d0b5-e019-470e-a17e-bc65a3ef0500/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dc14d0b5-e019-470e-a17e-bc65a3ef0500/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dc14d0b5-e019-470e-a17e-bc65a3ef0500/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dc14d0b5-e019-470e-a17e-bc65a3ef0500/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dc14d0b5-e019-470e-a17e-bc65a3ef0500/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dc14d0b5-e019-470e-a17e-bc65a3ef0500/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dc14d0b5-e019-470e-a17e-bc65a3ef0500/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dc14d0b5-e019-470e-a17e-bc65a3ef0500/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/dc14d0b5-e019-470e-a17e-bc65a3ef0500/thumbnailList"
      //       }
      //     },
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/previews/f548cb77-a829-42ea-b097-3b54603a0d8f/1631287550/preview.gif",
      //       "mime_type": "image/gif",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/8e39c487-72de-488d-b47b-6040cec9a900/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/8e39c487-72de-488d-b47b-6040cec9a900/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/8e39c487-72de-488d-b47b-6040cec9a900/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/8e39c487-72de-488d-b47b-6040cec9a900/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/8e39c487-72de-488d-b47b-6040cec9a900/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/8e39c487-72de-488d-b47b-6040cec9a900/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/8e39c487-72de-488d-b47b-6040cec9a900/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/8e39c487-72de-488d-b47b-6040cec9a900/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/8e39c487-72de-488d-b47b-6040cec9a900/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/8e39c487-72de-488d-b47b-6040cec9a900/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/8e39c487-72de-488d-b47b-6040cec9a900/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/8e39c487-72de-488d-b47b-6040cec9a900/thumbnailList"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "9",
      //   "chain": "eip155:1",
      //   "contract_address": "0xD8eed224E1B358fa6f7b167124C2c1AFe42275b4",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0xD8eed224E1B358fa6f7b167124C2c1AFe42275b4:84663873992476681896122431947515231738045062356454585024952296645344409704071",
      //   "token_number":
      //       "84663873992476681896122431947515231738045062356454585024952296645344409704071",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:12.384622Z",
      //   "metadata": {
      //     "name": "Entity #35",
      //     "description":
      //         "“Entity” is a wonderful dance of life. Colorful microorganisms are born, engage in naturalistic individual and group behaviors, evolve, and then terminate, making room for new specimens to emerge. The balletic choreography is governed not by linear animation but through the artist’s deep exploration and understanding of force-repulsion fields. Indeed, work with this complexity and nuance would seem impossible to animate by hand and feels closer to systems and behaviors we are accustomed to seeing only in nature. Such is the unique brilliance of Jared S Tarbell that his work does not capture nature, it rivals it. \n\nThis work is a programmed system and the video artifact was a capture of live interaction by the artist. The collectors will receive the interactive software as part of the acquisition. The music in this piece is “Infinity Machine” by Tonepoet.",
      //     "image_url":
      //         "https://cdn.feralfileassets.com/thumbnails/0698273e-13fc-43e9-910e-0f6d81827a01/1641571845",
      //     "animation_url":
      //         "https://cdn.feralfileassets.com/previews/0698273e-13fc-43e9-910e-0f6d81827a01/1641571880/preview.mp4",
      //     "mime_type": "video/mp4",
      //     "artists": [
      //       {"name": "Jared S Tarbell", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0xD9Ba9Efc69BDBAb198587f91B412Ae2c83298ef0",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0xf05db3a25b5cbc9e3a664a7ca92030b62ffafbdabc0b0beda36227e3ab93d3a0",
      //         "timestamp": "2024-03-01T08:26:47Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0xD9Ba9Efc69BDBAb198587f91B412Ae2c83298ef0",
      //         "tx_hash":
      //             "0x000ea9e24846416568ae655c9b0a13d859582f9d9566334ab317f58a7147824f",
      //         "timestamp": "2022-01-23T16:23:57Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/thumbnails/0698273e-13fc-43e9-910e-0f6d81827a01/1641571845",
      //       "mime_type": "image/png",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/2a7b6518-da48-47bf-0055-b992ae66f600/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/2a7b6518-da48-47bf-0055-b992ae66f600/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/2a7b6518-da48-47bf-0055-b992ae66f600/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/2a7b6518-da48-47bf-0055-b992ae66f600/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/2a7b6518-da48-47bf-0055-b992ae66f600/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/2a7b6518-da48-47bf-0055-b992ae66f600/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/2a7b6518-da48-47bf-0055-b992ae66f600/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/2a7b6518-da48-47bf-0055-b992ae66f600/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/2a7b6518-da48-47bf-0055-b992ae66f600/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/2a7b6518-da48-47bf-0055-b992ae66f600/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/2a7b6518-da48-47bf-0055-b992ae66f600/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/2a7b6518-da48-47bf-0055-b992ae66f600/thumbnailList"
      //       }
      //     },
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/previews/0698273e-13fc-43e9-910e-0f6d81827a01/1641571880/preview.mp4",
      //       "mime_type": "video/mp4",
      //       "variant_urls": {
      //         "hls":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/995c46aef12c6b649e10e40f82a9889d/manifest/video.m3u8",
      //         "dash":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/995c46aef12c6b649e10e40f82a9889d/manifest/video.mpd",
      //         "preview":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/995c46aef12c6b649e10e40f82a9889d/watch",
      //         "thumbnail":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/995c46aef12c6b649e10e40f82a9889d/thumbnails/thumbnail.jpg"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "10",
      //   "chain": "eip155:1",
      //   "contract_address": "0x7a15b36cB834AeA88553De69077D3777460d73Ac",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0x7a15b36cB834AeA88553De69077D3777460d73Ac:5280336779268220421569573059971679349075200194886069432279714075018412551154",
      //   "token_number":
      //       "5280336779268220421569573059971679349075200194886069432279714075018412551154",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:13.896391Z",
      //   "metadata": {
      //     "name": "Unsupervised — Data Universe — MoMA #2864",
      //     "description":
      //         "“Unsupervised — Data Universe — MoMA” is a global AI data painting that simulates a latent walk among the museum’s digitized collection. The artist and his team used MoMA archives to construct the seven dimensions of the artwork: x, y, z, r, g, b, and time. It combines Anadol’s vision of handling data within a universe that it creates for itself with his approach to data visualization’s latent space as a locus for never-ending, self-generating contemplation. Researcher Leland McInnes, the inventor of the UMAP technique that Anadol has used for “Unsupervised — Data Universe — MoMA” wrote, “I have always found beauty in mathematics, but to see what Refik has done with mathematics and these algorithms to create art is something else again: bringing together rich threads of information and data to weave amazing visual works. I never imagined that my work in mathematics could have such far reaching impacts.”",
      //     "image_url":
      //         "https://cdn.feralfileassets.com/thumbnails/e601569d-5611-4a82-93ba-a7f55b260001/1637053732",
      //     "animation_url":
      //         "https://cdn.feralfileassets.com/previews/e601569d-5611-4a82-93ba-a7f55b260001/1637053763/preview.mp4",
      //     "mime_type": "video/mp4",
      //     "artists": [
      //       {"name": "Refik Anadol", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x25a3e5C41be9beb1FFE5B8E3361a35184F9F5926",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0xa179b3c6ef2a81c8f41cb591d6e5cbea8e0e50018ee5fd30353200edd968ec32",
      //         "timestamp": "2024-02-05T04:19:47Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x9e9e7fcA2f0E13A1EAd11D18c03cdadB5A3B4CE0",
      //         "to_address": "0x25a3e5C41be9beb1FFE5B8E3361a35184F9F5926",
      //         "tx_hash":
      //             "0x96394d01701e75ae9cd92bc0535d60a54bb567620e823405a83e6b9280039c1b",
      //         "timestamp": "2022-11-10T03:50:11Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x4f820fD32eede8898d1b82e29ac7a2866FFbd459",
      //         "to_address": "0x9e9e7fcA2f0E13A1EAd11D18c03cdadB5A3B4CE0",
      //         "tx_hash":
      //             "0xc6654a05a2633cd79bbec35a981bd0b6aa539308ffeef8574af2489d032af7e0",
      //         "timestamp": "2022-06-24T04:17:35Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x9e9e7fcA2f0E13A1EAd11D18c03cdadB5A3B4CE0",
      //         "to_address": "0x4f820fD32eede8898d1b82e29ac7a2866FFbd459",
      //         "tx_hash":
      //             "0xdccd34310e24a8de20bcef3535637a08f15751cfada2e7054fbb2144af1346e2",
      //         "timestamp": "2022-04-23T20:56:25Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0xdDd3227CC48D04E5eA17E8B9dEf870c45160501E",
      //         "to_address": "0x9e9e7fcA2f0E13A1EAd11D18c03cdadB5A3B4CE0",
      //         "tx_hash":
      //             "0xd795d6d6582bca2e8ceb8286922cff2ff309b09110a3ea52038c50f533bc78a5",
      //         "timestamp": "2022-01-16T17:31:42Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0xdDd3227CC48D04E5eA17E8B9dEf870c45160501E",
      //         "tx_hash":
      //             "0xeecea8d21b181b2bbdb26f1df940ccf8be1e3b20a9233163db02f1c18b39dde6",
      //         "timestamp": "2022-01-16T11:15:46Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/thumbnails/e601569d-5611-4a82-93ba-a7f55b260001/1637053732",
      //       "mime_type": "image/jpeg",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/thumbnailList"
      //       }
      //     },
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/previews/e601569d-5611-4a82-93ba-a7f55b260001/1637053763/preview.mp4",
      //       "mime_type": "video/mp4",
      //       "variant_urls": {
      //         "hls":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/28626df0226deb475db3685f813eecf2/manifest/video.m3u8",
      //         "dash":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/28626df0226deb475db3685f813eecf2/manifest/video.mpd",
      //         "preview":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/28626df0226deb475db3685f813eecf2/watch",
      //         "thumbnail":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/28626df0226deb475db3685f813eecf2/thumbnails/thumbnail.jpg"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "12",
      //   "chain": "eip155:1",
      //   "contract_address": "0xE5163c74fFE6563D75d750E5d767122500a1c337",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0xE5163c74fFE6563D75d750E5d767122500a1c337:47896422095579711099185835491703333438573086439509639910123685376750831346263",
      //   "token_number":
      //       "47896422095579711099185835491703333438573086439509639910123685376750831346263",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:13.611411Z",
      //   "metadata": {
      //     "name": "k.f0 #8",
      //     "description":
      //         "p1xelfool&rsquo;s work creates tension by flattening moving 3D geometry into low resolution 2D graphics, and by contrasting high-fidelity physics simulations with extremely low-resolution graphics. The form and color create a strong reference to scientific diagrams, and more specifically to early representations of data within digital media. In &ldquo;k.f0,&rdquo; two opposing trails of particles rotate around the outside of a void marked with two coordinate axes that flicker in and out. Each particle, drawn as a small cluster of enlarged pixels, dissipates and dissolves as a constant stream of new material flows into the environment. The &ldquo;k.f0&rdquo; software is one of a pair of p1xelfool&rsquo;s first generative, live-code releases. We&rsquo;re thrilled to feature this new direction on Feral File.",
      //     "image_url":
      //         "https://cdn.feralfileassets.com/thumbnails/26433d62-bb36-46f8-bc8e-ed7214967cc2/1631213686",
      //     "animation_url":
      //         "https://cdn.feralfileassets.com/previews/26433d62-bb36-46f8-bc8e-ed7214967cc2/1631214206/index.html",
      //     "mime_type": "text/html; charset=utf-8",
      //     "artists": [
      //       {"name": "p1xelfool", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x619ee499477b293dA5df8FF48e1Ad00b81759900",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0xb75b055deb5e6231d228b5856d3077b0ad8c5cb74f4a1093b792e7c8e32887b9",
      //         "timestamp": "2024-01-13T08:12:47Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0xA0417f1696417a3541F04cc3aECE3B56ba273829",
      //         "to_address": "0x619ee499477b293dA5df8FF48e1Ad00b81759900",
      //         "tx_hash":
      //             "0x11e8e2c7ca33b58ee25ff419edb874381d0955c4d4e0aa6f364dae340f1daa04",
      //         "timestamp": "2023-04-22T17:46:11Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x28458F3442841dA5E4773b39286447D27EC57b59",
      //         "to_address": "0xA0417f1696417a3541F04cc3aECE3B56ba273829",
      //         "tx_hash":
      //             "0xde7c7a0a7b9364c9fceb7b262fd5b7ea89b137d366a3e3390442ed113fe9d503",
      //         "timestamp": "2023-02-05T11:36:23Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x80c939F8A66C59B37330f93f1002541fD4E51aa2",
      //         "to_address": "0x28458F3442841dA5E4773b39286447D27EC57b59",
      //         "tx_hash":
      //             "0x1460cec49fe8d5170e49c1d41c5ac2783f8f2c0cc359a401ff559d4dfc89e2b4",
      //         "timestamp": "2022-05-10T06:46:50Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0x80c939F8A66C59B37330f93f1002541fD4E51aa2",
      //         "tx_hash":
      //             "0x219c9192148ecfc2a8373cdbc4e0f13b057c459512af4986b66f93bf95b6ee80",
      //         "timestamp": "2021-12-13T21:57:43Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/thumbnails/26433d62-bb36-46f8-bc8e-ed7214967cc2/1631213686",
      //       "mime_type": "image/png",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1ddeec36-85bb-4213-48a3-b376d6264300/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1ddeec36-85bb-4213-48a3-b376d6264300/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1ddeec36-85bb-4213-48a3-b376d6264300/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1ddeec36-85bb-4213-48a3-b376d6264300/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1ddeec36-85bb-4213-48a3-b376d6264300/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1ddeec36-85bb-4213-48a3-b376d6264300/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1ddeec36-85bb-4213-48a3-b376d6264300/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1ddeec36-85bb-4213-48a3-b376d6264300/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1ddeec36-85bb-4213-48a3-b376d6264300/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1ddeec36-85bb-4213-48a3-b376d6264300/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1ddeec36-85bb-4213-48a3-b376d6264300/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/1ddeec36-85bb-4213-48a3-b376d6264300/thumbnailList"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "17",
      //   "chain": "eip155:1",
      //   "contract_address": "0x28b51BA8B990c48CB22cB6EF0ad5415fdBA5210C",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0x28b51BA8B990c48CB22cB6EF0ad5415fdBA5210C:81364566765837085577860824876328324342986698332133339997943493484390163948708",
      //   "token_number":
      //       "81364566765837085577860824876328324342986698332133339997943493484390163948708",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:12.610424Z",
      //   "metadata": {
      //     "name": "can I go where you go? #74",
      //     "description":
      //         "Maya Man&rsquo;s unique contribution to Social Codes offers a new way to think about software and performance. Her deep explorations in art, dance, and code come together in &ldquo;can I go where you go?&rdquo; As a video clip of Maya dancing plays, her code analyzes the video frames one by one to generate a silhouette. This contour becomes an ever&#45;changing shape the viewer can take charge of by drawing with it, or they can simply watch as the software performs itself.",
      //     "image_url":
      //         "https://cdn.feralfileassets.com/thumbnails/69518c54-2bc5-4b90-b606-675529c7593d/1615837791",
      //     "animation_url":
      //         "https://cdn.feralfileassets.com/previews/69518c54-2bc5-4b90-b606-675529c7593d/1615845070/index.html",
      //     "mime_type": "text/html; charset=utf-8",
      //     "artists": [
      //       {"name": "Maya Man", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0xD9Ba9Efc69BDBAb198587f91B412Ae2c83298ef0",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0x452f878c2974b59ebe5e611159a37a7c769f37a3fbc10aab850d027374067b6f",
      //         "timestamp": "2023-10-20T15:42:23Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0xD9Ba9Efc69BDBAb198587f91B412Ae2c83298ef0",
      //         "tx_hash":
      //             "0xa611d8fd8c64e77ab4e0423a8bd429c67df89908ba41b18f9c747d6082397196",
      //         "timestamp": "2022-03-26T15:26:33Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/thumbnails/69518c54-2bc5-4b90-b606-675529c7593d/1615837791",
      //       "mime_type": "image/png",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/6abf4006-40a8-498b-4b6e-57cf55c14f00/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/6abf4006-40a8-498b-4b6e-57cf55c14f00/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/6abf4006-40a8-498b-4b6e-57cf55c14f00/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/6abf4006-40a8-498b-4b6e-57cf55c14f00/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/6abf4006-40a8-498b-4b6e-57cf55c14f00/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/6abf4006-40a8-498b-4b6e-57cf55c14f00/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/6abf4006-40a8-498b-4b6e-57cf55c14f00/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/6abf4006-40a8-498b-4b6e-57cf55c14f00/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/6abf4006-40a8-498b-4b6e-57cf55c14f00/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/6abf4006-40a8-498b-4b6e-57cf55c14f00/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/6abf4006-40a8-498b-4b6e-57cf55c14f00/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/6abf4006-40a8-498b-4b6e-57cf55c14f00/thumbnailList"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "11",
      //   "chain": "eip155:1",
      //   "contract_address": "0x6DBa130221A1C39f6623908A136976686050059a",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0x6DBa130221A1C39f6623908A136976686050059a:95818392624963223466242622248667825872377430497511423781312150293054165540134",
      //   "token_number":
      //       "95818392624963223466242622248667825872377430497511423781312150293054165540134",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:12.554669Z",
      //   "metadata": {
      //     "name": "Smart Cut #87",
      //     "description":
      //         "According to the art critic Arthur C. Danto, “To see something as art requires something the eye cannot decry—an atmosphere of artistic theory, a knowledge of the history of art: an artworld.” Since 2014, Jonas Lund has been making abstract paintings using elements sampled from paintings by other emerging artists, optimized for market success. The morphing animations in “Smart Cut” are made out of images from this series that were not selected for production: works as part of the process, works as they were before they got “good,” left-over abstractions. Turned into animations, these discarded images—not art, according to Lund's “artistic theory”—have been selected by a smart cut algorithm as the best ones and automatically pieced together.",
      //     "image_url":
      //         "https://cdn.feralfileassets.com/thumbnails/25a3d5d3-43a6-495e-bf18-e0583fa11f72/1638616961",
      //     "animation_url":
      //         "https://cdn.feralfileassets.com/previews/25a3d5d3-43a6-495e-bf18-e0583fa11f72/1638568442/preview.mp4",
      //     "mime_type": "video/mp4",
      //     "artists": [
      //       {"name": "Jonas Lund", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x5FCd30A446D465ebB0FF8dB85FEb19fE98D758f5",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0xbb3f0c46218a5e7ec0fe61d7e0c8bcf0d4ba29b74d7878d5d0717cf8467a2150",
      //         "timestamp": "2023-10-20T13:10:23Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0x5FCd30A446D465ebB0FF8dB85FEb19fE98D758f5",
      //         "tx_hash":
      //             "0x5a68de243ba3ad7f633b98bb7e976aae72a59f53c344ee5622101473c320dcf5",
      //         "timestamp": "2022-07-02T11:39:54Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/thumbnails/25a3d5d3-43a6-495e-bf18-e0583fa11f72/1638616961",
      //       "mime_type": "image/jpeg",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/26b67195-ccb8-4419-d245-db5c82554300/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/26b67195-ccb8-4419-d245-db5c82554300/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/26b67195-ccb8-4419-d245-db5c82554300/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/26b67195-ccb8-4419-d245-db5c82554300/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/26b67195-ccb8-4419-d245-db5c82554300/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/26b67195-ccb8-4419-d245-db5c82554300/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/26b67195-ccb8-4419-d245-db5c82554300/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/26b67195-ccb8-4419-d245-db5c82554300/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/26b67195-ccb8-4419-d245-db5c82554300/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/26b67195-ccb8-4419-d245-db5c82554300/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/26b67195-ccb8-4419-d245-db5c82554300/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/26b67195-ccb8-4419-d245-db5c82554300/thumbnailList"
      //       }
      //     },
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/previews/25a3d5d3-43a6-495e-bf18-e0583fa11f72/1638568442/preview.mp4",
      //       "mime_type": "video/mp4",
      //       "variant_urls": {
      //         "hls":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/dc01c7973ba5e55657a93aa11f4f749a/manifest/video.m3u8",
      //         "dash":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/dc01c7973ba5e55657a93aa11f4f749a/manifest/video.mpd",
      //         "preview":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/dc01c7973ba5e55657a93aa11f4f749a/watch",
      //         "thumbnail":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/dc01c7973ba5e55657a93aa11f4f749a/thumbnails/thumbnail.jpg"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "18",
      //   "chain": "eip155:1",
      //   "contract_address": "0x6DBa130221A1C39f6623908A136976686050059a",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0x6DBa130221A1C39f6623908A136976686050059a:33302801400363962874789470259095989022217858728739498634567156886587995359897",
      //   "token_number":
      //       "33302801400363962874789470259095989022217858728739498634567156886587995359897",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:12.274868Z",
      //   "metadata": {
      //     "name": "ماه طلعت، Moon-faced #99",
      //     "description":
      //         "In ancient Persian literature,  ماه طلعت، (“Moon-faced”) was a genderless adjective used to define beauty in both men and women. In contemporary Iran, it refers to the beauty of women only. Something similar happened, in the world of images, to the Qajar dynasty portrait paintings: the modernization of Iran, the influence of the European tradition of realistic painting, and the use of of camera technology and therefore photography as a model, overshadowed and ended the queer representation of genders that historically characterized these paintings, largely known for their gender-undifferentiation. For her project, “ماه طلعت، Moon-faced,” Allahyari uses a carefully researched and chosen series of keywords with a multimodal AI model to generate a series of videos from the Qajar Dynasty painting archive (1786-1925). Through this collaboration, the machine program learns to paint new genderless portraits, in the effort to undo and repair a history of Westernization that ended the course of nonbinary gender representation in the Persian visual culture. The music in this video was composed by Mani Nilchiani.",
      //     "image_url":
      //         "https://ipfs.io/ipfs/QmNS2P5LxpH4ezHrCjHUwsfEjP4ru6HHFFXZNJt9sVmMPh",
      //     "animation_url":
      //         "https://ipfs.io/ipfs/QmefSHPAq5YEt3suS1qPgSHuFaQ8YEBSHzUPUZrR9RQkTW",
      //     "mime_type": "video/mp4",
      //     "artists": [
      //       {"name": "Morehshin Allahyari", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0x0d515f7d601723d781024c83d5d3c6872a654b628581d71b6acdf862ec442bdd",
      //         "timestamp": "2023-10-19T10:59:47Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://ipfs.io/ipfs/QmNS2P5LxpH4ezHrCjHUwsfEjP4ru6HHFFXZNJt9sVmMPh",
      //       "mime_type": "image/jpeg",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/3d5d6929-251d-4d81-0ba3-e97e2f6c1300/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/3d5d6929-251d-4d81-0ba3-e97e2f6c1300/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/3d5d6929-251d-4d81-0ba3-e97e2f6c1300/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/3d5d6929-251d-4d81-0ba3-e97e2f6c1300/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/3d5d6929-251d-4d81-0ba3-e97e2f6c1300/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/3d5d6929-251d-4d81-0ba3-e97e2f6c1300/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/3d5d6929-251d-4d81-0ba3-e97e2f6c1300/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/3d5d6929-251d-4d81-0ba3-e97e2f6c1300/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/3d5d6929-251d-4d81-0ba3-e97e2f6c1300/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/3d5d6929-251d-4d81-0ba3-e97e2f6c1300/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/3d5d6929-251d-4d81-0ba3-e97e2f6c1300/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/3d5d6929-251d-4d81-0ba3-e97e2f6c1300/thumbnailList"
      //       }
      //     },
      //     {
      //       "source_url":
      //           "https://ipfs.io/ipfs/QmefSHPAq5YEt3suS1qPgSHuFaQ8YEBSHzUPUZrR9RQkTW",
      //       "mime_type": "video/mp4",
      //       "variant_urls": {
      //         "hls":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/27b602c49f15a5691dbb96f535598957/manifest/video.m3u8",
      //         "dash":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/27b602c49f15a5691dbb96f535598957/manifest/video.mpd",
      //         "preview":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/27b602c49f15a5691dbb96f535598957/watch",
      //         "thumbnail":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/27b602c49f15a5691dbb96f535598957/thumbnails/thumbnail.jpg"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "16",
      //   "chain": "eip155:1",
      //   "contract_address": "0x7a15b36cB834AeA88553De69077D3777460d73Ac",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0x7a15b36cB834AeA88553De69077D3777460d73Ac:5280336779268220421569573059971679349075200194886069432279714075018412549358",
      //   "token_number":
      //       "5280336779268220421569573059971679349075200194886069432279714075018412549358",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:14.229657Z",
      //   "metadata": {
      //     "name": "Unsupervised — Data Universe — MoMA #1068",
      //     "description":
      //         "“Unsupervised — Data Universe — MoMA” is a global AI data painting that simulates a latent walk among the museum’s digitized collection. The artist and his team used MoMA archives to construct the seven dimensions of the artwork: x, y, z, r, g, b, and time. It combines Anadol’s vision of handling data within a universe that it creates for itself with his approach to data visualization’s latent space as a locus for never-ending, self-generating contemplation. Researcher Leland McInnes, the inventor of the UMAP technique that Anadol has used for “Unsupervised — Data Universe — MoMA” wrote, “I have always found beauty in mathematics, but to see what Refik has done with mathematics and these algorithms to create art is something else again: bringing together rich threads of information and data to weave amazing visual works. I never imagined that my work in mathematics could have such far reaching impacts.”",
      //     "image_url":
      //         "https://cdn.feralfileassets.com/thumbnails/e601569d-5611-4a82-93ba-a7f55b260001/1637053732",
      //     "animation_url":
      //         "https://cdn.feralfileassets.com/previews/e601569d-5611-4a82-93ba-a7f55b260001/1637053763/preview.mp4",
      //     "mime_type": "video/mp4",
      //     "artists": [
      //       {"name": "Refik Anadol", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x661A427e0FB519e6DB8Eca57D9d3a561B16ccFC6",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0x23b52c1c4689bb2c031be3c900097294eb4456fa9c0abda64b6fb4fdc4513942",
      //         "timestamp": "2023-10-14T03:50:23Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0xC3C221aB225ef8c7d83377Ccc513c8284DBB4d86",
      //         "to_address": "0x661A427e0FB519e6DB8Eca57D9d3a561B16ccFC6",
      //         "tx_hash":
      //             "0x09a87fb29b4fd580f7dd912e2ec45cabd80b5ece9b614905974bd1e7f43307a6",
      //         "timestamp": "2023-09-26T14:50:11Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x8Fd46f7c618C064f9217C33f98C87a422D4e9Cb1",
      //         "to_address": "0xC3C221aB225ef8c7d83377Ccc513c8284DBB4d86",
      //         "tx_hash":
      //             "0x710dbc33493947f5f74276b3ee92728f234af455118a336855c7602188711b46",
      //         "timestamp": "2023-07-17T09:12:35Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x8F80737840917584D5bf4d8653a23d71fD92c3CF",
      //         "to_address": "0x8Fd46f7c618C064f9217C33f98C87a422D4e9Cb1",
      //         "tx_hash":
      //             "0x0d7bae174117d87c07c3092be72ff764530f3e9da06a4fc74d6280f4bc71bedb",
      //         "timestamp": "2023-07-11T12:05:23Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x9934C1269a94A09CfACB1f123fE8660CfFd0D55b",
      //         "to_address": "0x8F80737840917584D5bf4d8653a23d71fD92c3CF",
      //         "tx_hash":
      //             "0x9ea908a70afed1e2c880cdbd4dcc9463e1bdca159e2f3fbb6823c44f824d3333",
      //         "timestamp": "2022-01-20T12:32:53Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0x9934C1269a94A09CfACB1f123fE8660CfFd0D55b",
      //         "tx_hash":
      //             "0x6eb57453dc940547cd987582806904ed09d8de80bdcc5161d4556baefb57ea8b",
      //         "timestamp": "2021-12-18T11:01:11Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/thumbnails/e601569d-5611-4a82-93ba-a7f55b260001/1637053732",
      //       "mime_type": "image/jpeg",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/thumbnailList"
      //       }
      //     },
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/previews/e601569d-5611-4a82-93ba-a7f55b260001/1637053763/preview.mp4",
      //       "mime_type": "video/mp4",
      //       "variant_urls": {
      //         "hls":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/28626df0226deb475db3685f813eecf2/manifest/video.m3u8",
      //         "dash":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/28626df0226deb475db3685f813eecf2/manifest/video.mpd",
      //         "preview":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/28626df0226deb475db3685f813eecf2/watch",
      //         "thumbnail":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/28626df0226deb475db3685f813eecf2/thumbnails/thumbnail.jpg"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "14",
      //   "chain": "eip155:1",
      //   "contract_address": "0x28b51BA8B990c48CB22cB6EF0ad5415fdBA5210C",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0x28b51BA8B990c48CB22cB6EF0ad5415fdBA5210C:53850398982106570267917421068933678215838025172652046814035972200709896037650",
      //   "token_number":
      //       "53850398982106570267917421068933678215838025172652046814035972200709896037650",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:12.906428Z",
      //   "metadata": {
      //     "name": "dada data #31",
      //     "description":
      //         "LIA was a pioneer in creating internet art in the 1990s, and since then, she has continued to experiment and explore into the present. Her latest work, &ldquo;dada data,&rdquo; is aligned with her early works in its focus on minimal, generative animation. With a red dot as a focal point, a network of lines undulate and coil left and right in a way that nods to Marcel Duchamp&rsquo;s hypnotic &ldquo;Rotoreliefs.&rdquo; Although the linear forms that comprise &ldquo;dada data&quot; are minimal, the motion is complex and entirely engrossing.",
      //     "image_url":
      //         "https://ipfs.io/ipfs/QmPfdPZgrqSSBGPxvXTTFu8CAe1zEzn43FWLytf7FYiY8W",
      //     "animation_url":
      //         "https://ipfs.io/ipfs/QmSCPSiToTUWq2K7JsupsyPVPskSDTPfVAsMUVJcHhqgKh?edition_number=31&blockchain=bitmark",
      //     "mime_type": "text/html; charset=utf-8",
      //     "artists": [
      //       {"name": "LIA", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x8264e9e0f4CbcBBbb3F8eCAec0A625B590Ae790e",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0x015274db3b5c8327a0a2cd5eb085f4100d2ff5eb2da20b3f6367c6b43e2ceedd",
      //         "timestamp": "2023-10-10T00:31:59Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x6A0af60C1906cC788d301acfCBF4B8B54E4a9A10",
      //         "to_address": "0x8264e9e0f4CbcBBbb3F8eCAec0A625B590Ae790e",
      //         "tx_hash":
      //             "0x95db60609641782f776d621ee9b6a0820037f81a30cd06d48c19bab165a2f191",
      //         "timestamp": "2023-10-08T19:02:35Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0x6A0af60C1906cC788d301acfCBF4B8B54E4a9A10",
      //         "tx_hash":
      //             "0xc0e83167fc1dd23d82ee20d1281fbd9d3e70cffbbb1ff49beb4522dcbd31e3e5",
      //         "timestamp": "2023-05-31T07:30:47Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://ipfs.io/ipfs/QmPfdPZgrqSSBGPxvXTTFu8CAe1zEzn43FWLytf7FYiY8W",
      //       "mime_type": "image/jpeg",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/5b982991-dc54-4474-a581-016c1c0e2f00/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/5b982991-dc54-4474-a581-016c1c0e2f00/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/5b982991-dc54-4474-a581-016c1c0e2f00/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/5b982991-dc54-4474-a581-016c1c0e2f00/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/5b982991-dc54-4474-a581-016c1c0e2f00/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/5b982991-dc54-4474-a581-016c1c0e2f00/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/5b982991-dc54-4474-a581-016c1c0e2f00/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/5b982991-dc54-4474-a581-016c1c0e2f00/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/5b982991-dc54-4474-a581-016c1c0e2f00/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/5b982991-dc54-4474-a581-016c1c0e2f00/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/5b982991-dc54-4474-a581-016c1c0e2f00/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/5b982991-dc54-4474-a581-016c1c0e2f00/thumbnailList"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "15",
      //   "chain": "eip155:1",
      //   "contract_address": "0x7a15b36cB834AeA88553De69077D3777460d73Ac",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0x7a15b36cB834AeA88553De69077D3777460d73Ac:5280336779268220421569573059971679349075200194886069432279714075018412549088",
      //   "token_number":
      //       "5280336779268220421569573059971679349075200194886069432279714075018412549088",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:12.456262Z",
      //   "metadata": {
      //     "name": "Unsupervised — Data Universe — MoMA #798",
      //     "description":
      //         "“Unsupervised — Data Universe — MoMA” is a global AI data painting that simulates a latent walk among the museum’s digitized collection. The artist and his team used MoMA archives to construct the seven dimensions of the artwork: x, y, z, r, g, b, and time. It combines Anadol’s vision of handling data within a universe that it creates for itself with his approach to data visualization’s latent space as a locus for never-ending, self-generating contemplation. Researcher Leland McInnes, the inventor of the UMAP technique that Anadol has used for “Unsupervised — Data Universe — MoMA” wrote, “I have always found beauty in mathematics, but to see what Refik has done with mathematics and these algorithms to create art is something else again: bringing together rich threads of information and data to weave amazing visual works. I never imagined that my work in mathematics could have such far reaching impacts.”",
      //     "image_url":
      //         "https://ipfs.io/ipfs/QmNuJ5kHgqHYPPb4LKz3WtFGYQURo7zt5qiJuSjzsh7s2L",
      //     "animation_url":
      //         "https://ipfs.io/ipfs/QmP84LnTz5TGu1VpsY3GtkQJjx1BsZXtLTEzUqFXMCz21k",
      //     "mime_type": "video/mp4",
      //     "artists": [
      //       {"name": "Refik Anadol", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x85376adEc0c715BCD98C25Da1D1319429C9765e6",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0x3385e1ebefc5242c01a67ad405ee7cb2097e93185851fd7ba60fa926d9610c0d",
      //         "timestamp": "2023-09-28T04:45:47Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0x85376adEc0c715BCD98C25Da1D1319429C9765e6",
      //         "tx_hash":
      //             "0x11c5fc917ab7a401527c4c51cc66068d531a5d0c9f0cb1357f7ef338cec1d275",
      //         "timestamp": "2023-04-15T16:08:47Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://ipfs.io/ipfs/QmNuJ5kHgqHYPPb4LKz3WtFGYQURo7zt5qiJuSjzsh7s2L",
      //       "mime_type": "image/jpeg",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/7bf4f0d6-80a5-4567-119c-f3dc50209600/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/7bf4f0d6-80a5-4567-119c-f3dc50209600/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/7bf4f0d6-80a5-4567-119c-f3dc50209600/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/7bf4f0d6-80a5-4567-119c-f3dc50209600/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/7bf4f0d6-80a5-4567-119c-f3dc50209600/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/7bf4f0d6-80a5-4567-119c-f3dc50209600/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/7bf4f0d6-80a5-4567-119c-f3dc50209600/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/7bf4f0d6-80a5-4567-119c-f3dc50209600/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/7bf4f0d6-80a5-4567-119c-f3dc50209600/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/7bf4f0d6-80a5-4567-119c-f3dc50209600/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/7bf4f0d6-80a5-4567-119c-f3dc50209600/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/7bf4f0d6-80a5-4567-119c-f3dc50209600/thumbnailList"
      //       }
      //     },
      //     {
      //       "source_url":
      //           "https://ipfs.io/ipfs/QmP84LnTz5TGu1VpsY3GtkQJjx1BsZXtLTEzUqFXMCz21k",
      //       "mime_type": "video/mp4",
      //       "variant_urls": {
      //         "hls":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/cde56dc26122990876caaea9c1c35c95/manifest/video.m3u8",
      //         "dash":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/cde56dc26122990876caaea9c1c35c95/manifest/video.mpd",
      //         "preview":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/cde56dc26122990876caaea9c1c35c95/watch",
      //         "thumbnail":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/cde56dc26122990876caaea9c1c35c95/thumbnails/thumbnail.jpg"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // },
      // {
      //   "id": "3",
      //   "chain": "eip155:1",
      //   "contract_address": "0x7a15b36cB834AeA88553De69077D3777460d73Ac",
      //   "standard": "erc721",
      //   "token_cid":
      //       "eip155:1:erc721:0x7a15b36cB834AeA88553De69077D3777460d73Ac:5280336779268220421569573059971679349075200194886069432279714075018412552751",
      //   "token_number":
      //       "5280336779268220421569573059971679349075200194886069432279714075018412552751",
      //   "current_owner": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //   "updated_at": "2025-11-03T06:50:12.581581Z",
      //   "metadata": {
      //     "name": "Unsupervised — Data Universe — MoMA #4461",
      //     "description":
      //         "“Unsupervised — Data Universe — MoMA” is a global AI data painting that simulates a latent walk among the museum’s digitized collection. The artist and his team used MoMA archives to construct the seven dimensions of the artwork: x, y, z, r, g, b, and time. It combines Anadol’s vision of handling data within a universe that it creates for itself with his approach to data visualization’s latent space as a locus for never-ending, self-generating contemplation. Researcher Leland McInnes, the inventor of the UMAP technique that Anadol has used for “Unsupervised — Data Universe — MoMA” wrote, “I have always found beauty in mathematics, but to see what Refik has done with mathematics and these algorithms to create art is something else again: bringing together rich threads of information and data to weave amazing visual works. I never imagined that my work in mathematics could have such far reaching impacts.”",
      //     "image_url":
      //         "https://cdn.feralfileassets.com/thumbnails/e601569d-5611-4a82-93ba-a7f55b260001/1637053732",
      //     "animation_url":
      //         "https://cdn.feralfileassets.com/previews/e601569d-5611-4a82-93ba-a7f55b260001/1637053763/preview.mp4",
      //     "mime_type": "video/mp4",
      //     "artists": [
      //       {"name": "Refik Anadol", "did": ""}
      //     ],
      //     "publisher": {"name": "Feral File", "url": "https://feralfile.com"}
      //   },
      //   "owners": {
      //     "items": [
      //       {
      //         "quantity": "1",
      //         "owner_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8"
      //       }
      //     ]
      //   },
      //   "provenance_events": {
      //     "items": [
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x02c465d39Fa7E876D1Cd74be886323c2a66eF9E6",
      //         "to_address": "0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8",
      //         "tx_hash":
      //             "0x9cc913c72f4efa582fabc59208755403dbfd8b32e77d95b70a4c8e2d594b7f4c",
      //         "timestamp": "2023-09-17T05:38:47Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "transfer",
      //         "from_address": "0x64bd1995E7FBE51506d8EDF40E8E24a422C46558",
      //         "to_address": "0x02c465d39Fa7E876D1Cd74be886323c2a66eF9E6",
      //         "tx_hash":
      //             "0x49a08a9b05c22297a1edcd5a91b12ffa3716fee94ef8de73542b52312e844251",
      //         "timestamp": "2023-09-05T02:36:35Z",
      //         "chain": "eip155:1"
      //       },
      //       {
      //         "event_type": "mint",
      //         "from_address": "0x0000000000000000000000000000000000000000",
      //         "to_address": "0x64bd1995E7FBE51506d8EDF40E8E24a422C46558",
      //         "tx_hash":
      //             "0x8301b89701e8a41e29ce1142e5421640854b141570260577f756654506f83523",
      //         "timestamp": "2021-12-19T10:04:43Z",
      //         "chain": "eip155:1"
      //       }
      //     ]
      //   },
      //   "enrichment_source": null,
      //   "metadata_media_assets": [
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/thumbnails/e601569d-5611-4a82-93ba-a7f55b260001/1637053732",
      //       "mime_type": "image/jpeg",
      //       "variant_urls": {
      //         "l":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/l",
      //         "m":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/m",
      //         "s":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/s",
      //         "xl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/xl",
      //         "xs":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/xs",
      //         "raw":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/raw",
      //         "xxl":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/xxl",
      //         "small":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/small",
      //         "public":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/public",
      //         "preview":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/preview",
      //         "thumbnail":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/thumbnail",
      //         "thumbnailList":
      //             "https://imagedelivery.net/iCRs13uicXIPOWrnuHbaKA/79c90770-67cd-4085-4380-baa57a02f100/thumbnailList"
      //       }
      //     },
      //     {
      //       "source_url":
      //           "https://cdn.feralfileassets.com/previews/e601569d-5611-4a82-93ba-a7f55b260001/1637053763/preview.mp4",
      //       "mime_type": "video/mp4",
      //       "variant_urls": {
      //         "hls":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/28626df0226deb475db3685f813eecf2/manifest/video.m3u8",
      //         "dash":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/28626df0226deb475db3685f813eecf2/manifest/video.mpd",
      //         "preview":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/28626df0226deb475db3685f813eecf2/watch",
      //         "thumbnail":
      //             "https://customer-vt0p8j34ppjv1kd4.cloudflarestream.com/28626df0226deb475db3685f813eecf2/thumbnails/thumbnail.jpg"
      //       }
      //     }
      //   ],
      //   "enrichment_source_media_assets": null
      // }
    ],
    "offset": null,
    "total": "17"
  }
};
