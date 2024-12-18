@Timeout(Duration(minutes: 12))

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../lib/src/util.dart';

const tempDirName = 'temp-mini';

void main() async {
  final rootPath = path.join(Directory.current.path, '..', '..');
  final cliPath = path.join(rootPath, 'tools', 'serverpod_cli');
  final tempPath = path.join(rootPath, tempDirName);

  setUpAll(() async {
    await Process.run(
      'dart',
      ['pub', 'global', 'activate', '-s', 'path', '.'],
      workingDirectory: cliPath,
    );

    await Process.run('mkdir', [tempDirName], workingDirectory: rootPath);
  });

  tearDownAll(() async {
    try {
      await Process.run(
        'rm',
        ['-rf', tempDirName],
        workingDirectory: rootPath,
      );
    } catch (e) {}
  });

  group('Given a clean state', () {
    final (:projectName, :commandRoot) = createRandomProjectName(tempPath);

    late Process createProcess;

    test(
        'when creating a new project with the mini template then the project is created successfully and can be booted in maintenance mode.',
        () async {
      createProcess = await Process.start(
        'serverpod',
        ['create', '--template', 'mini', projectName, '-v', '--no-analytics'],
        workingDirectory: tempPath,
        environment: {
          'SERVERPOD_HOME': rootPath,
        },
      );

      createProcess.stdout.transform(Utf8Decoder()).listen(print);
      createProcess.stderr.transform(Utf8Decoder()).listen(print);

      var createProjectExitCode = await createProcess.exitCode;
      expect(
        createProjectExitCode,
        0,
        reason: 'Failed to create the serverpod project.',
      );

      var startProcess = await Process.start(
        'dart',
        ['bin/main.dart', '--role', 'maintenance'],
        workingDirectory: commandRoot,
      );

      startProcess.stdout.transform(Utf8Decoder()).listen(print);
      startProcess.stderr.transform(Utf8Decoder()).listen(print);

      var startProjectExitCode = await startProcess.exitCode;
      expect(startProjectExitCode, 0);
    });
  });

  group('Given a clean state', () {
    final (:projectName, :commandRoot) = createRandomProjectName(tempPath);

    late Process createProcess;

    test(
        'when creating a new project with the mini template then the project is created successfully without the full configuration of a full project.',
        () async {
      createProcess = await Process.start(
        'serverpod',
        ['create', '--template', 'mini', projectName, '-v', '--no-analytics'],
        workingDirectory: tempPath,
        environment: {
          'SERVERPOD_HOME': rootPath,
        },
      );

      createProcess.stdout.transform(Utf8Decoder()).listen(print);
      createProcess.stderr.transform(Utf8Decoder()).listen(print);

      var createProjectExitCode = await createProcess.exitCode;
      expect(
        createProjectExitCode,
        0,
        reason: 'Failed to create the serverpod project.',
      );

      final serverDir = createServerFolderPath(projectName);

      var configDir =
          Directory(path.join(tempPath, serverDir, 'config')).existsSync();
      expect(
        configDir,
        isFalse,
        reason: 'No config directory should exist but it was found.',
      );

      var deployDir =
          Directory(path.join(tempPath, serverDir, 'deploy')).existsSync();
      expect(
        deployDir,
        isFalse,
        reason: 'No deploy directory should exist but it was found.',
      );

      var webDir =
          Directory(path.join(tempPath, serverDir, 'web')).existsSync();
      expect(
        webDir,
        isFalse,
        reason: 'No web directory should exist but it was found.',
      );

      var dockerComposeFile =
          File(path.join(tempPath, serverDir, 'docker-compose.yaml'))
              .existsSync();
      expect(
        dockerComposeFile,
        isFalse,
        reason: 'No docker-compose.yml should exist but it was found.',
      );

      var gcloudIgnoreFile =
          File(path.join(tempPath, serverDir, '.gcloudignore')).existsSync();
      expect(
        gcloudIgnoreFile,
        isFalse,
        reason: 'No .gcloudignore should exist but it was found.',
      );
    });
  });

  group('Given a clean state', () {
    final (:projectName, :commandRoot) = createRandomProjectName(tempPath);
    final serverDir = createServerFolderPath(projectName);
    late Process createProcess;

    tearDown(() async {
      await Process.run(
        'docker',
        ['compose', 'down', '-v'],
        workingDirectory: commandRoot,
      );
    });

    test(
        'when creating a new project with the mini template and upgrading it to a full project then the project is created successfully and can be booted in maintenance mode with the apply-migrations flag.',
        () async {
      createProcess = await Process.start(
        'serverpod',
        ['create', '--template', 'mini', projectName, '-v', '--no-analytics'],
        workingDirectory: tempPath,
        environment: {
          'SERVERPOD_HOME': rootPath,
        },
      );

      createProcess.stdout.transform(Utf8Decoder()).listen(print);
      createProcess.stderr.transform(Utf8Decoder()).listen(print);

      var createProjectExitCode = await createProcess.exitCode;
      expect(
        createProjectExitCode,
        0,
        reason: 'Failed to create the serverpod project.',
      );

      var upgradeProcess = await Process.start(
        'serverpod',
        ['create', '--template', 'server', '.', '-v', '--no-analytics'],
        workingDirectory: path.join(tempPath, serverDir),
        environment: {
          'SERVERPOD_HOME': rootPath,
        },
      );

      upgradeProcess.stdout.transform(Utf8Decoder()).listen(print);
      upgradeProcess.stderr.transform(Utf8Decoder()).listen(print);

      var upgradeProjectExitCode = await upgradeProcess.exitCode;
      expect(
        upgradeProjectExitCode,
        0,
        reason: 'Failed to create the serverpod project.',
      );

      final docker = await Process.start(
        'docker',
        ['compose', 'up', '--build', '--detach'],
        workingDirectory: commandRoot,
      );

      docker.stdout.transform(Utf8Decoder()).listen(print);
      docker.stderr.transform(Utf8Decoder()).listen(print);

      var dockerExitCode = await docker.exitCode;

      expect(
        dockerExitCode,
        0,
        reason: 'Docker with postgres failed to start.',
      );

      var startProcess = await Process.start(
        'dart',
        ['bin/main.dart', '--apply-migrations', '--role', 'maintenance'],
        workingDirectory: commandRoot,
      );

      startProcess.stdout.transform(Utf8Decoder()).listen(print);
      startProcess.stderr.transform(Utf8Decoder()).listen(print);

      var startProjectExitCode = await startProcess.exitCode;
      expect(startProjectExitCode, 0);
    });
  });

  group('Given a clean state', () {
    final (:projectName, :commandRoot) = createRandomProjectName(tempPath);
    final serverDir = createServerFolderPath(projectName);
    late Process createProcess;
    tearDown(() async {
      createProcess.kill();
    });

    test(
        'when creating a new project with the mini template and upgrading it to a full project then the project is created successfully and can be booted in maintenance mode with the apply-migrations flag.',
        () async {
      createProcess = await Process.start(
        'serverpod',
        ['create', '--template', 'mini', projectName, '-v', '--no-analytics'],
        workingDirectory: tempPath,
        environment: {
          'SERVERPOD_HOME': rootPath,
        },
      );

      createProcess.stdout.transform(Utf8Decoder()).listen(print);
      createProcess.stderr.transform(Utf8Decoder()).listen(print);

      var createProjectExitCode = await createProcess.exitCode;
      expect(
        createProjectExitCode,
        0,
        reason: 'Failed to create the serverpod project.',
      );

      var upgradeProcess = await Process.start(
        'serverpod',
        ['create', '--template', 'server', '.', '-v', '--no-analytics'],
        workingDirectory: path.join(tempPath, serverDir),
        environment: {
          'SERVERPOD_HOME': rootPath,
        },
      );

      upgradeProcess.stdout.transform(Utf8Decoder()).listen(print);
      upgradeProcess.stderr.transform(Utf8Decoder()).listen(print);

      var upgradeProjectExitCode = await upgradeProcess.exitCode;
      expect(
        upgradeProjectExitCode,
        0,
        reason: 'Failed to create the serverpod project.',
      );

      var configDir =
          Directory(path.join(tempPath, serverDir, 'config')).existsSync();
      expect(
        configDir,
        isTrue,
        reason: 'Config directory should exist but it was not found.',
      );

      var deployDir =
          Directory(path.join(tempPath, serverDir, 'deploy')).existsSync();
      expect(
        deployDir,
        isTrue,
        reason: 'Deploy directory should exist but it was not found.',
      );

      var webDir =
          Directory(path.join(tempPath, serverDir, 'web')).existsSync();
      expect(
        webDir,
        isTrue,
        reason: 'Web directory should exist but it was not found.',
      );

      var dockerFile =
          File(path.join(tempPath, serverDir, 'Dockerfile')).existsSync();
      expect(
        dockerFile,
        isTrue,
        reason: 'Dockerfile should exist but it was not found.',
      );

      var dockerComposeFile =
          File(path.join(tempPath, serverDir, 'docker-compose.yaml'))
              .existsSync();
      expect(
        dockerComposeFile,
        isTrue,
        reason: 'docker-compose.yml should exist but it was not found.',
      );

      var gcloudIgnoreFile =
          File(path.join(tempPath, serverDir, '.gcloudignore')).existsSync();
      expect(
        gcloudIgnoreFile,
        isTrue,
        reason: '.gcloudignore should exist but it was not found.',
      );
    });
  });

  group('Given a clean state', () {
    final (:projectName, :commandRoot) = createRandomProjectName(tempPath);
    final serverDir = createServerFolderPath(projectName);
    late Process createProcess;
    tearDown(() async {
      createProcess.kill();

      await Process.run(
        'docker',
        ['compose', 'down', '-v'],
        workingDirectory: commandRoot,
      );

      while (!await isNetworkPortAvailable(8090));
    });

    test(
        'when creating a new project with the mini template and upgrading it to a full project then the tests are passing.',
        () async {
      createProcess = await Process.start(
        'serverpod',
        ['create', '--template', 'mini', projectName, '-v', '--no-analytics'],
        workingDirectory: tempPath,
        environment: {
          'SERVERPOD_HOME': rootPath,
        },
      );

      createProcess.stdout.transform(Utf8Decoder()).listen(print);
      createProcess.stderr.transform(Utf8Decoder()).listen(print);

      var createProjectExitCode = await createProcess.exitCode;
      expect(
        createProjectExitCode,
        0,
        reason: 'Failed to create the serverpod project.',
      );

      var upgradeProcess = await Process.start(
        'serverpod',
        ['create', '--template', 'server', '.', '-v', '--no-analytics'],
        workingDirectory: path.join(tempPath, serverDir),
        environment: {
          'SERVERPOD_HOME': rootPath,
        },
      );

      upgradeProcess.stdout.transform(Utf8Decoder()).listen(print);
      upgradeProcess.stderr.transform(Utf8Decoder()).listen(print);

      var upgradeProjectExitCode = await upgradeProcess.exitCode;
      expect(
        upgradeProjectExitCode,
        0,
        reason: 'Failed to upgrade the serverpod project.',
      );

      final docker = await Process.start(
        'docker',
        ['compose', 'up', '--build', '--detach'],
        workingDirectory: commandRoot,
      );

      docker.stdout.transform(Utf8Decoder()).listen(print);
      docker.stderr.transform(Utf8Decoder()).listen(print);

      var dockerExitCode = await docker.exitCode;

      expect(
        dockerExitCode,
        0,
        reason: 'Docker with postgres failed to start.',
      );

      var testProcess = await Process.run(
        'dart',
        ['test'],
        workingDirectory:
            path.join(tempPath, projectName, "${projectName}_server"),
      );

      expect(testProcess.exitCode, 0, reason: 'Tests are failing.');
    });
  });

  group('Given a created mini project', () {
    final (:projectName, :commandRoot) = createRandomProjectName(tempPath);

    setUp(() async {
      var createProcess = await Process.run(
        'serverpod',
        ['create', '--template', 'mini', projectName, '-v', '--no-analytics'],
        workingDirectory: tempPath,
        environment: {
          'SERVERPOD_HOME': rootPath,
        },
      );
      assert((await createProcess.exitCode) == 0);
    });

    test('when running tests then example unit and integration tests passes',
        () async {
      var testProcess = await Process.run(
        'dart',
        ['test'],
        workingDirectory:
            path.join(tempPath, projectName, "${projectName}_server"),
      );

      expect(testProcess.exitCode, 0);
    });
  });
}
