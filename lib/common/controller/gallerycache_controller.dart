import 'dart:collection';
import 'dart:convert';

import 'package:fehviewer/common/controller/webdav_controller.dart';
import 'package:fehviewer/models/base/eh_models.dart';
import 'package:fehviewer/pages/image_view/common.dart';
import 'package:fehviewer/store/get_store.dart';
import 'package:fehviewer/utils/logger.dart';
import 'package:get/get.dart';
import 'package:throttling/throttling.dart';

import '../../pages/gallery/controller/gallery_page_state.dart';

const _kMaxPageState = 60;

class GalleryCacheController extends GetxController {
  final GStore gStore = Get.find<GStore>();
  final WebdavController webdavController = Get.find();
  LinkedHashMap<String, GalleryCache> gCacheMap = LinkedHashMap();

  // final thrSync = Throttling(duration: const Duration(seconds: 10));
  final debSync = Debouncing(duration: const Duration(seconds: 5));

  Future<GalleryCache?> getGalleryCache(String gid, {bool sync = true}) async {
    final _localCache = gStore.getCache(gid);

    if (!gCacheMap.containsKey(gid) && _localCache != null) {
      logger.v('get from store');
      gCacheMap[gid] = _localCache;
    }

    if (!sync || !webdavController.syncReadProgress) {
      return gCacheMap[gid];
    } else {
      try {
        final remotelist = await webdavController.getRemotReadList();
        logger.v('remotelist $remotelist');
        if (remotelist.contains(gid)) {
          final remote = await webdavController.downloadRead(gid);
          logger.v('remote ${remote?.toJson()}');
          if (_localCache == null && remote != null) {
            logger.v('local null');
            gCacheMap[gid] = GalleryCache(lastIndex: remote.lastIndex);
          } else if (_localCache != null && remote != null) {
            logger.v('both not null');
            if ((remote.time ?? 0) > (_localCache.time ?? 0)) {
              gCacheMap[gid] = _localCache.copyWith(
                  lastIndex: remote.lastIndex, time: remote.time);
            }
          }
        }
      } catch (e) {
        return gCacheMap[gid];
      }
    }
    return gCacheMap[gid];
  }

  Future<void> setIndex(String gid, int index,
      {bool saveToStore = false}) async {
    final GalleryCache? _ori = await getGalleryCache(gid, sync: false);
    final _time = DateTime.now().millisecondsSinceEpoch;
    if (_ori == null) {
      final _newCache = GalleryCache(gid: gid, lastIndex: index, time: _time);
      gCacheMap[gid] = _newCache;
      if (saveToStore) {
        gStore.saveCache(_newCache);
        if (webdavController.syncReadProgress) {
          debSync.debounce(() => webdavController.uploadRead(_newCache));
        }
      }
    } else {
      final _newCache = _ori.copyWith(lastIndex: index, time: _time);
      gCacheMap[gid] = _newCache;
      if (saveToStore) {
        gStore.saveCache(_newCache);
        if (webdavController.syncReadProgress) {
          debSync.debounce(() => webdavController.uploadRead(_newCache));
        }
      }
    }
  }

  void saveAll() {
    logger.v(
        'save All GalleryCache \n${gCacheMap.entries.map((e) => jsonEncode(e.value)).join('\n')}');
    gCacheMap.forEach((key, value) {
      gStore.saveCache(value);
    });
  }

  Future<void> setColumnMode(String gid, ViewColumnMode columnMode) async {
    final GalleryCache? _ori = await getGalleryCache(gid, sync: false);
    if (_ori == null) {
      gCacheMap[gid] = GalleryCache(gid: gid).copyWithMode(columnMode);
      gStore.saveCache(GalleryCache(gid: gid).copyWithMode(columnMode));
    } else {
      gCacheMap[gid] = _ori.copyWithMode(columnMode);
      gStore.saveCache(_ori.copyWithMode(columnMode));
    }
  }

  // 缓存GalleryPageState
  final List<GalleryPageState> pageStateList = [];

  void addGalleryPageState(GalleryPageState state) {
    if (state.firstPageImage.isEmpty) {
      return;
    }

    final index =
        pageStateList.indexWhere((element) => element.gid == state.gid);
    if (index > -1) {
      pageStateList[index] = state;
    } else {
      if (pageStateList.length + 1 > _kMaxPageState) {
        pageStateList.removeAt(0);
      }
      pageStateList.add(state);
    }
    logger.v(
        'pageStateList\n${pageStateList.map((e) => '${e.title} - ${e.galleryProvider?.favcat}').join('\n')}');
  }

  GalleryPageState? getGalleryPageState(String gid) {
    return pageStateList.firstWhereOrNull((element) => element.gid == gid);
  }
}
