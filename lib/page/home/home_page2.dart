import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class HomePage2 extends StatefulWidget {
  final TeamModel teamModel;
  const HomePage2({super.key, required this.teamModel});

  @override
  State<HomePage2> createState() => _HomePage2State();
}

class _HomePage2State extends State<HomePage2> {
  @override
  Widget build(BuildContext context) {
    return Consumer<TeamProvider>(
      builder: (context, teamProvider, child) {
        final selectedTeam = teamProvider.selectedTeam ?? widget.teamModel;
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 100,
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              '두산 베어스',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            leading: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'assets/images/korean_logo/bears.png',
                fit: BoxFit.contain,
              ),
            ),

            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_none,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],

            flexibleSpace: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(selectedTeam.headers, fit: BoxFit.cover),
                  Container(color: Colors.black.withValues(alpha: 0.15)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
