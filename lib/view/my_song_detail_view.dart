import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:spiewnik/model/my_song_model.dart';
import 'package:spiewnik/view/delete_my_song_dialog.dart';
import 'package:spiewnik/view/my_song_form_view.dart';
import 'package:spiewnik/viewmodel/my_song_viewmodel.dart';
import 'package:spiewnik/view/screen_wake_lock.dart';
import 'package:spiewnik/view/widgets/song_content.dart';
import 'package:spiewnik/view/widgets/song_options_sheet.dart';

class MySongDetailView extends StatefulWidget {
  final MySong song;
  final MySongViewModel viewModel;

  /// „Dodaj do listy” (Add to list) in the options; without it the option is not there.
  final void Function(BuildContext context, MySong song)? onAddToPlaylist;

  const MySongDetailView({super.key, required this.song, required this.viewModel, this.onAddToPlaylist});

  @override
  MySongDetailViewState createState() => MySongDetailViewState();
}

class MySongDetailViewState extends State<MySongDetailView> {
  /// Anchor for the share sheet on iPad, where it is a popover next to the button.
  final GlobalKey _optionsButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    ScreenWakeLock.acquire();
  }

  @override
  void dispose() {
    ScreenWakeLock.release();
    super.dispose();
  }

  Future<void> _share() async {
    final box = _optionsButtonKey.currentContext?.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: widget.song.content,
        subject: widget.song.title,
        // Required on iPad, where the share sheet is a popover anchored to the button.
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MySongFormView(viewModel: widget.viewModel, song: widget.song)),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmMySongDeletion(context, widget.song);
    if (!confirmed || !mounted) {
      return;
    }
    widget.viewModel.deleteSong(widget.song);
    Navigator.pop(context);
  }

  /// Options sheet from the three dots, the same as in the songbook song view.
  /// Items close the sheet **before** the action, so neither the system share sheet nor the form
  /// opens on top of ours.
  Future<void> _showOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      builder: (sheetContext) => SongOptionsSheet(
        options: [
          SongOption(
            icon: Icons.ios_share,
            label: 'Udostępnij pieśń',
            onTap: () {
              Navigator.pop(sheetContext);
              _share();
            },
          ),
          if (widget.onAddToPlaylist != null)
            SongOption(
              icon: Icons.playlist_add,
              label: 'Dodaj do listy',
              onTap: () {
                Navigator.pop(sheetContext);
                widget.onAddToPlaylist!(context, widget.song);
              },
            ),
          SongOption(
            icon: Icons.edit,
            label: 'Edytuj pieśń',
            onTap: () {
              Navigator.pop(sheetContext);
              _edit();
            },
          ),
          SongOption(
            icon: Icons.delete_outline,
            label: 'Usuń pieśń',
            destructive: true,
            onTap: () {
              Navigator.pop(sheetContext);
              _delete();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          widget.song.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18.0,
          ),
        ),
        actions: [
          IconButton(
            key: _optionsButtonKey,
            tooltip: 'Opcje pieśni',
            onPressed: _showOptions,
            icon: const Icon(Icons.more_vert, size: 24.0),
          ),
        ],
      ),
      body: SongContent(content: widget.song.content),
    );
  }
}
