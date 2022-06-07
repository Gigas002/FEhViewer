import 'package:dio/dio.dart';
import 'package:fehviewer/common/controller/cache_controller.dart';
import 'package:fehviewer/common/controller/download_controller.dart';
import 'package:fehviewer/common/controller/gallerycache_controller.dart';
import 'package:fehviewer/common/controller/history_controller.dart';
import 'package:fehviewer/common/controller/localfav_controller.dart';
import 'package:fehviewer/common/parser/eh_parser.dart';
import 'package:fehviewer/common/service/controller_tag_service.dart';
import 'package:fehviewer/common/service/ehconfig_service.dart';
import 'package:fehviewer/common/service/layout_service.dart';
import 'package:fehviewer/component/exception/error.dart';
import 'package:fehviewer/fehviewer.dart';
import 'package:fehviewer/network/app_dio/pdio.dart';
import 'package:fehviewer/network/api.dart';
import 'package:fehviewer/network/request.dart';
import 'package:fehviewer/pages/gallery/gallery_repository.dart';
import 'package:fehviewer/pages/gallery/view/const.dart';
import 'package:fehviewer/pages/gallery/view/gallery_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'all_previews_controller.dart';
import 'comment_controller.dart';
import 'gallery_fav_controller.dart';
import 'gallery_page_state.dart';
import 'taginfo_controller.dart';
import 'torrent_controller.dart';

const double kHeaderHeightOffset = kHeaderHeight + 52.0;

class GalleryPageController extends GetxController
    with StateMixin<GalleryProvider> {
  GalleryPageController();

  late final GalleryPageState gState;

  // 滚动控制器
  late ScrollController scrollController;

  // eh设置
  final EhConfigService _ehConfigService = Get.find();
  final HistoryController _historyController = Get.find();
  final GalleryCacheController _galleryCacheController = Get.find();
  DownloadController get _downloadController => Get.find();
  final CacheController _cacheController = Get.find();

  @override
  void onInit() {
    super.onInit();

    logger.v('GalleryPageController $pageCtrlTag onInit');

    final galleryRepository = Get.find<GalleryRepository>();
    bool isStateFromCache = false;

    if (galleryRepository.url != null && galleryRepository.url!.isNotEmpty) {
      // url跳转
      // 解析gid等信息
      final RegExp urlRex =
          RegExp(r'(http?s://e[-x]hentai.org)?/g/(\d+)/(\w+)/?$');
      final RegExpMatch? urlRult =
          urlRex.firstMatch(galleryRepository.url ?? '');
      final String gid = urlRult?.group(2) ?? '';
      final String token = urlRult?.group(3) ?? '';

      if (!_loadDataFromCache(
        gid,
        isStateFromCacheChange: (val) => isStateFromCache = val,
      )) {
        gState = GalleryPageState();
        gState.fromUrl = true;
        gState.galleryProvider =
            GalleryProvider(url: galleryRepository.url, gid: gid, token: token);
      }
    } else {
      if (!_loadDataFromCache(
        galleryRepository.item?.gid ?? '',
        isStateFromCacheChange: (val) => isStateFromCache = val,
      )) {
        gState = GalleryPageState();
        gState.galleryProvider = galleryRepository.item!;
      }
    }

    gState.hideNavigationBtn = true;

    if (!isStateFromCache) {
      logger.v('state new load');
      gState.galleryRepository = galleryRepository;
      _loadData();

      // 初始
      _galleryCacheController
          .getGalleryCache(gState.galleryProvider?.gid ?? '')
          .then((_galleryCache) =>
              gState.lastIndex = _galleryCache?.lastIndex ?? 0);
    }
  }

  // @override
  // void onReady() {
  //   super.onReady();
  //   scrollController = PrimaryScrollController.of(Get.context!)!;
  //   scrollController.addListener(scrollControllerLister);
  // }

  @override
  void onClose() {
    scrollController.dispose();
    logger.v('onClose GalleryPageController $pageCtrlTag');
    super.onClose();
    // _galleryCacheController.addGalleryPageState(gState);
  }

  Future<void> _loadData({bool refresh = false, bool showError = true}) async {
    try {
      final GalleryProvider? _fetchItem = await _fetchData(refresh: refresh);
      change(_fetchItem, status: RxStatus.success());
      time.showTime('change end');

      gState.enableRead = true;

      // 跳转提示dialog
      if (gState.galleryRepository?.jumpSer != null) {
        startReadDialog(gState.galleryRepository!.jumpSer!);
      }
    } catch (err, stack) {
      logger.e('$err\n$stack');
      String errMsg = err.toString();
      if (err is EhError) {
        errMsg = err.message;
      }
      if (showError) {
        change(null, status: RxStatus.error(errMsg));
      }
    }
  }

  /// 请求数据
  Future<GalleryProvider?> _fetchData({bool refresh = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    try {
      gState.hideNavigationBtn = true;

      if (gState.galleryProvider != null &&
          (gState.galleryProvider?.filecount == null ||
              (gState.galleryProvider?.filecount?.isEmpty ?? true))) {
        gState.galleryProvider = await Api.getMoreGalleryInfoOne(
            gState.galleryProvider!,
            refresh: refresh);
      }

      // 检查画廊是否包含在本地收藏中
      final bool _localFav = _isInLocalFav(gState.galleryProvider?.gid ?? '0');
      gState.galleryProvider =
          gState.galleryProvider?.copyWith(localFav: _localFav);

      final String? _oriColorRating = gState.galleryProvider?.colorRating;
      final String? _oriRatingCount = gState.galleryProvider?.ratingCount;
      final double? _oriRatingFallBack = gState.galleryProvider?.ratingFallBack;
      final bool? _oriIsRatinged = gState.galleryProvider?.isRatinged;

      time.showTime('start get galleryProvider');
      final fetchedGalleryProvider = await getGalleryDetail(
        url: gState.galleryProvider?.url ?? '',
        refresh: refresh,
      );
      time.showTime('fetch galleryProvider end');

      if (fetchedGalleryProvider != null) {
        gState.galleryProvider =
            gState.galleryProvider?.copyWithAll(fetchedGalleryProvider);
      }

      gState.currentImagePage = 0;
      setImageAfterRequest(gState.galleryProvider?.galleryImages);

      // 评论
      gState.comments(gState.galleryProvider?.galleryComment);

      try {
        // 页面内刷新时的处理
        if (refresh) {
          // 评分状态更新
          gState.isRatinged = gState.galleryProvider?.isRatinged ?? false;
        } else {
          gState.galleryProvider = gState.galleryProvider?.copyWith(
            ratingFallBack:
                gState.galleryProvider?.ratingFallBack ?? _oriRatingFallBack,
            ratingCount: gState.galleryProvider?.ratingCount ?? _oriRatingCount,
            colorRating: _oriColorRating,
            // isRatinged: _oriIsRatinged,
          );

          // 评分状态更新
          gState.isRatinged = gState.galleryProvider?.isRatinged ?? false;

          // 收藏控制器状态更新
          final GalleryFavController _favController =
              Get.find(tag: pageCtrlTag);
          _favController.setFav(gState.galleryProvider?.favcat ?? '',
              gState.galleryProvider?.favTitle ?? '');
        }
      } catch (_) {}

      gState.galleryProvider = gState.galleryProvider?.copyWith(
          imgUrl: gState.galleryProvider?.imgUrl ??
              gState.galleryProvider?.imgUrlL);

      // 加入历史
      if (gState.galleryProvider != null &&
          gState.galleryProvider?.gid != null) {
        Future<void>.delayed(const Duration(milliseconds: 700)).then((_) {
          _historyController.addHistory(gState.galleryProvider!);
        });
      }

      update([GetIds.PAGE_VIEW_HEADER]);
      gState.itemController?.update([gState.gid]);
      return gState.galleryProvider;
    } on HttpException catch (e) {
      throw EhError(error: e.message);
    } on DioError catch (e) {
      if (e.type == DioErrorType.response && e.response?.statusCode == 404) {
        logger.e('data: ${e.response?.data}');
        final errMsg = parseErrGallery('${e.response?.data ?? ''}');
        logger.e('errMsg: $errMsg');
        throw EhError(error: errMsg);
      }
      rethrow;
    } catch (e, stack) {
      logger.e('解析数据异常\n' + e.toString() + '\n' + stack.toString());
      throw EhError(error: 'Parsing data error');
    }
  }

  bool _loadDataFromCache(
    String gid, {
    ValueChanged<bool>? isStateFromCacheChange,
  }) {
    final stateFromCache = _galleryCacheController.getGalleryPageState(gid);
    if (stateFromCache != null) {
      gState = stateFromCache;
      isStateFromCacheChange?.call(true);
      change(gState.galleryProvider, status: RxStatus.success());
      Future<void>.delayed(const Duration(milliseconds: 700)).then((_) {
        _historyController.addHistory(gState.galleryProvider!);
      });
      return true;
    } else {
      return false;
    }
  }

  // 评分后更新ui和数据
  void ratinged({
    required double ratingUsr,
    required double ratingAvg,
    required int ratingCnt,
    required String colorRating,
  }) {
    gState.isRatinged = true;

    gState.galleryProvider = gState.galleryProvider?.copyWith(
      isRatinged: true,
      ratingFallBack: ratingUsr,
      rating: ratingAvg,
      ratingCount: ratingCnt.toString(),
      colorRating: colorRating,
    );

    // gState.itemController?.galleryProvider = gState.galleryProvider!;

    // logger.d('update GetIds.PAGE_VIEW_HEADER');
    update([GetIds.PAGE_VIEW_HEADER]);
    gState.itemController?.ratingFB =
        gState.galleryProvider?.ratingFallBack ?? 0.0;

    gState.itemController?.update();
  }

  void uptImageBySer({required int ser, required GalleryImage image}) {
    final int? _index = gState.galleryProvider?.galleryImages
        ?.indexWhere((GalleryImage element) => element.ser == ser);
    if (_index != null && _index >= 0) {
      gState.galleryProvider?.galleryImages?[_index] = image;
    }
  }

  void setImageAfterRequest(List<GalleryImage>? images) {
    if (images?.isNotEmpty ?? false) {
      gState.galleryProvider =
          gState.galleryProvider?.copyWith(galleryImages: images);
    }

    gState.firstPageImage =
        gState.galleryProvider?.galleryImages?.sublist(0, images?.length) ?? [];
  }

  /// 添加缩略图对象
  void addAllImages(List<GalleryImage> galleryImages) {
    logger5.v(
        'addAllPreview ${galleryImages.first.ser}~${galleryImages.last.ser} ');

    for (final GalleryImage _image in galleryImages) {
      final int index =
          gState.images.indexWhere((GalleryImage e) => e.ser == _image.ser);
      if (index != -1) {
        gState.images[index] = _image;
      } else {
        gState.images.add(_image);
      }
    }
  }

  Future<void> startReadDialog(int ser) async {
    await showCupertinoDialog<void>(
      context: Get.overlayContext!,
      barrierDismissible: true,
      builder: (context) {
        return CupertinoAlertDialog(
          // title: Text(L10n.of(context).jump_to_page),
          // title: Text('${L10n.of(context).jump_to_page} $ser?'),
          title: Text('Start reading on page $ser ?'),
          actions: [
            CupertinoDialogAction(
              child: Text(L10n.of(Get.context!).cancel),
              onPressed: () {
                Get.back();
              },
            ),
            CupertinoDialogAction(
              child: Text(
                L10n.of(Get.context!).ok,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              onPressed: () {
                Get.back();
                NavigatorUtil.goGalleryViewPage(ser - 1, gState.gid);
              },
            ),
          ],
        );
      },
    );
  }

  // 刷新重载
  Future<void> _reloadData() async {
    gState.isRefresh = true;
    try {
      Get.find<TorrentController>(tag: pageCtrlTag).isRefresh = true;
    } catch (e) {
      logger.e('$e');
    }
    await _loadData(refresh: true, showError: false);
  }

  Future<void> handOnRefresh() async {
    await _reloadData();
  }

  Future<void> handOnRefreshAfterErr() async {
    change(null, status: RxStatus.loading());
    _fetchData(refresh: true).then((GalleryProvider? value) {
      gState.enableRead = true;
      change(value, status: RxStatus.success());
    });
  }

  bool _isInLocalFav(String gid) {
    // 检查是否包含在本地收藏中
    final int index = Get.find<LocalFavController>()
        .loacalFavs
        .indexWhere((GalleryProvider element) {
      return element.gid == gid;
    });
    return index >= 0;
  }

  void scrollControllerLister() {
    if (scrollController == null) {
      return;
    }
    try {
      if (scrollController.offset < kHeaderHeightOffset + kHeaderPaddingTop &&
          !gState.hideNavigationBtn) {
        gState.hideNavigationBtn = true;
      } else if (scrollController.offset >=
              kHeaderHeightOffset + kHeaderPaddingTop &&
          gState.hideNavigationBtn) {
        gState.hideNavigationBtn = false;
      }
    } catch (_) {}
  }

  /// 拉取直到index的缩略图信息
  Future<void> showDialogFetchImageUntilIndex(
      BuildContext context, int index) async {
    return showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext context) {
        Future<void>.delayed(const Duration(milliseconds: 0))
            .then((_) => loadPriviewUntilIndex(index))
            .whenComplete(() => Get.back());

        return Center(
          child: CupertinoPopupSurface(
            child: Container(
                height: 80,
                width: 80,
                alignment: Alignment.center,
                child: const CupertinoActivityIndicator(
                  radius: 20,
                )),
          ),
        );
      },
    );
  }

  /// 加载下一页缩略图
  Future<void> _loarMordPriview({CancelToken? cancelToken}) async {
    // 增加延时 避免build期间进行 setState
    await Future<void>.delayed(const Duration(milliseconds: 0));

    logger.v(
        '获取更多预览 ${gState.galleryProvider?.url} : ${gState.currentImagePage}');

    final List<GalleryImage> _moreGalleryImageList = await getGalleryImage(
      gState.galleryProvider?.url ?? '',
      page: gState.currentImagePage + 1,
      cancelToken: cancelToken,
      refresh: gState.isRefresh,
    );

    gState.currentImagePage++;
    addAllImages(_moreGalleryImageList);
    if (Get.isRegistered<AllPreviewsPageController>()) {
      Get.find<AllPreviewsPageController>().update();
    }
  }

  /// 直接请求目的index所在的缩略图页
  Future<void> loadImagesForSer(int ser, {CancelToken? cancelToken}) async {
    // TODO(w): 优化重复触发

    //  计算index所在的页码
    final int flen = gState.firstPageImage.length;
    if (gState.filecount <= flen) {
      return;
    }

    final int page = (ser - 1) ~/ flen;
    logger.d('ser:$ser 所在页码为$page');

    gState.mapLoadImagesForSer.putIfAbsent(
        page,
        () => getGalleryImage(
              gState.galleryProvider?.url ?? '',
              page: page,
              cancelToken: cancelToken,
              refresh: gState.isRefresh, // 刷新画廊后加载缩略图不能从缓存读取，否则在改变每页数量后加载画廊会出错
            ));

    final List<GalleryImage> _moreImageList =
        await gState.mapLoadImagesForSer[page]!;

    addAllImages(_moreImageList);
    if (Get.isRegistered<AllPreviewsPageController>()) {
      Get.find<AllPreviewsPageController>().update();
    }
    gState.mapLoadImagesForSer.remove(page);
  }

  // 按顺序翻页加载缩略图对象
  Future<bool> loadPriviewUntilIndex(int index) async {
    final List<GalleryImage>? _galleryImageList =
        gState.galleryProvider?.galleryImages;

    if (_galleryImageList == null) {
      return true;
    }

    while (index > _galleryImageList.length - 1) {
      logger.d(' index = $index ; len = ${_galleryImageList.length}');
      await _loarMordPriview();
    }
    return true;
  }

  /// 获取当前页的图片信息
  Future<GalleryImage?> fetchAndParserImageInfo(
    int itemSer, {
    CancelToken? cancelToken,
    // bool refresh = false,
    bool changeSource = false,
  }) async {
    try {
      /// 当前缩略图对象
      final GalleryImage? _curImages =
          gState.galleryProvider?.imageMap[itemSer];

      if (_curImages == null) {
        return null;
      }

      final String? _largeImageUrl = _curImages.imageUrl;

      // 大图url为空或者宽高信息为空的时候 都会解析获取
      if (_largeImageUrl != null &&
          _largeImageUrl.isNotEmpty &&
          _curImages.imageHeight != null &&
          _curImages.imageWidth != null) {
        return gState.galleryProvider?.imageMap[itemSer];
      } else {
        final String? _sourceId = changeSource
            ? gState.galleryProvider?.imageMap[itemSer]?.sourceId
            : '';

        logger.d(
            'ser:$itemSer ,href: ${gState.galleryProvider?.imageMap[itemSer]?.href} , _sourceId: $_sourceId');

        try {
          if (changeSource) {
            // 删除旧缓存
            _cacheController.clearDioCache(
                path: gState.galleryProvider?.imageMap[itemSer]?.href ?? '');
          }

          // 加载当前页信息
          final GalleryImage? _image = await fetchImageInfo(
            gState.galleryProvider?.imageMap[itemSer]?.href ?? '',
            sourceId: _sourceId,
          );

          logger.v('fetch _image ${_image?.toJson()}');

          // 换源加载
          if (changeSource) {
            logger5.d('itemSer$itemSer 换源加载 ${_image?.imageUrl}');
          }

          if (_image == null) {
            return _curImages;
          }

          final GalleryImage _imageCopyWith = _curImages.copyWith(
            sourceId: _image.sourceId,
            imageUrl: _image.imageUrl,
            imageWidth: _image.imageWidth,
            imageHeight: _image.imageHeight,
            originImageUrl: _image.originImageUrl,
          );

          logger.v('_imageCopyWith ${_imageCopyWith.toJson()}');

          uptImageBySer(ser: itemSer, image: _imageCopyWith);
          return _imageCopyWith;
        } catch (_) {
          rethrow;
        }
      }
    } catch (e, stack) {
      logger.e('fetchAndParserImageInfo error\n$e \n $stack');
      rethrow;
    }
  }

  void downloadGallery(BuildContext context) {
    switch (_ehConfigService.downloadOrigType) {
      case DownloadOrigImageType.no:
        _downloadGallery();
        break;
      case DownloadOrigImageType.always:
        _downloadGallery(downloadOri: true);
        break;
      case DownloadOrigImageType.askMe:
        showCupertinoDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) {
              return CupertinoAlertDialog(
                title: Text(L10n.of(context).image_download_type),
                // content: Text(L10n.of(context).download_ori_image_summary),
                actions: [
                  CupertinoDialogAction(
                    child: Text(L10n.of(context).resample_image),
                    onPressed: () {
                      Get.back();
                      _downloadGallery();
                    },
                  ),
                  CupertinoDialogAction(
                    child: Text(L10n.of(context).original_image),
                    onPressed: () {
                      Get.back();
                      _downloadGallery(downloadOri: true);
                    },
                  ),
                ],
              );
            });
        break;
    }
  }

  void _downloadGallery({bool downloadOri = false}) {
    _downloadController.downloadGallery(
      gid: int.parse(gState.gid),
      token: gState.galleryProvider?.token,
      url: gState.galleryProvider?.url ?? '',
      fileCount: int.parse(gState.galleryProvider?.filecount ?? '0'),
      title: gState.title,
      coverUrl: gState.galleryProvider?.imgUrl,
      rating: gState.galleryProvider?.rating,
      uploader: gState.galleryProvider?.uploader,
      category: gState.galleryProvider?.category,
      downloadOri: downloadOri,
    );
  }

  Future<void> addTag() async {
    final dynamic _rult = await Get.toNamed(
      EHRoutes.addTag,
      id: isLayoutLarge ? 2 : null,
    );
    if (_rult != null && _rult is String) {
      logger.v('addTag $_rult');
      final TagInfoController? controller =
          Get.put(TagInfoController(), tag: pageCtrlTag);
      controller?.tagVoteUp(_rult);
    }
  }
}
