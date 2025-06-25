// import 'package:flutter/cupertino.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
//
// final nameProvider = Provider<String>((ref){
//  return "gautam";
// });
//
// class MyWidget extends ConsumerWidget{
//   Widget build(BuildContext context,WidgetRef ref){
//     final name = ref.watch(nameProvider);
//     return Text("Hello $name",);
//   }
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final nameProvider = Provider<String>((ref) {
  return "Gautam";
});

class MyWidget extends ConsumerWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(nameProvider);
    return Text("Hello $name");
  }
}

final dataProvider = FutureProvider((ref) async {
  await Future.delayed(Duration(seconds: 2));
  return "data Loaded";
});

class AsyncExample extends ConsumerWidget {
  const AsyncExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(dataProvider);
    return asyncValue.when(
      data: (data) => Text(data),
      error: (error, stackTrace) => Text("Error $error"),
      loading: () => CircularProgressIndicator(),
    );
  }
}

final counterProvider = StateProvider((ref) => 0);

class CounterProvider extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Column(
      children: [
        Text("Count $count"),
        ElevatedButton(
          onPressed: () {
            ref.read(counterProvider.notifier).state++;
          },
          child: Text("Increment"),
        ),
      ],
    );
  }
}

final timeProvider = StreamProvider((ref) {
  return Stream.periodic(
    Duration(seconds: 1),
    (computationCount) => computationCount,
  );
});

class TimerWidget extends ConsumerWidget {
  const TimerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = ref.watch(timeProvider);
    return time.when(
      data: (data) => Text("Seconds: $data"),
      error: (error, stackTrace) => Text("Error $error"),
      loading: () => CircularProgressIndicator(),
    );
  }
}

class CounterNotification extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

final counterNotifierProvider = NotifierProvider<CounterNotification, int>(
  () => CounterNotification(),
);

class NotifierExample extends ConsumerWidget {
  const NotifierExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterNotifierProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Count: $count'),
        ElevatedButton(
          onPressed: () {
            ref.read(counterNotifierProvider.notifier).increment();
          },
          child: Text('Increment'),
        ),
      ],
    );
  }
}
