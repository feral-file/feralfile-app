//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/nft_collection/models/token.dart';
import 'package:floor/floor.dart';

@dao
abstract class TokenDao {
  @Query('SELECT id FROM Token')
  Future<List<String>> findAllTokenIDs();

  @Query('SELECT id FROM Token where owner IN (:owners)')
  Future<List<String>> findTokenIDsByOwners(List<String> owners);

  @Query('SELECT id FROM Token where owner IN (:owners) AND balance > 0')
  Future<List<String>> findTokenIDsOwnersOwn(List<String> owners);

  @Query('SELECT * FROM Token WHERE id = (:id)')
  Future<List<Token>> findTokensByID(String id);

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertTokens(List<Token> assets);

  @Insert(onConflict: OnConflictStrategy.ignore)
  Future<void> insertTokensAbort(List<Token> assets);

  @Query('DELETE FROM Token WHERE id IN (:ids)')
  Future<void> deleteTokens(List<String> ids);

  @Query('DELETE FROM Token WHERE id = (:id)')
  Future<void> deleteTokenByID(String id);

  @Query('DELETE FROM Token WHERE owner IN (:owners)')
  Future<void> deleteTokensByOwners(List<String> owners);

  @Query('DELETE FROM Token')
  Future<void> removeAll();
}

/** MARK: - Important!
 *** Because of limitation of Floor, please override this in auto-generated app_database.g.dart

    @override
    Future<List<String>> findAllTokenIDs() async {
    return _queryAdapter.queryList('SELECT id FROM Token',
    mapper: (Map<String, Object?> row) => row['id'] as String);
    }
 */
