import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../logic/cubits/account_cubit.dart';
import '../../data/models/account_model.dart';

class AccountLastDigitsScreen extends StatelessWidget {
  const AccountLastDigitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Account Last Digits'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.08),
              Theme.of(context).colorScheme.secondary.withOpacity(0.08),
            ],
          ),
        ),
        child: SafeArea(
          child: BlocBuilder<AccountCubit, AccountState>(
            builder: (context, state) {
              if (state is AccountLoading || state is AccountInitial) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is AccountError) {
                return Center(child: Text(state.message));
              }
              if (state is AccountLoaded) {
                final accounts = state.accounts;
                if (accounts.isEmpty) {
                  return const Center(child: Text('No accounts found'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: accounts.length,
                  itemBuilder: (context, index) {
                    return _AccountDigitsTile(account: accounts[index], index: index);
                  },
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }
}

class _AccountDigitsTile extends StatefulWidget {
  final AccountModel account;
  final int index;
  const _AccountDigitsTile({required this.account, required this.index});

  @override
  State<_AccountDigitsTile> createState() => _AccountDigitsTileState();
}

class _AccountDigitsTileState extends State<_AccountDigitsTile> {
  late final TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.account.lastDigits ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.96),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.account_balance, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.account.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _isEditing = !_isEditing);
                    },
                    icon: Icon(_isEditing ? Icons.close : Icons.edit),
                    tooltip: _isEditing ? 'Cancel' : 'Edit',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_isEditing) ...[
                Row(
                  children: [
                    const Text(
                      'Last digits:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        widget.account.lastDigits?.isNotEmpty == true
                            ? '•••• ${widget.account.lastDigits}'
                            : 'Not set',
                        style: TextStyle(
                          color: widget.account.lastDigits?.isNotEmpty == true
                              ? Colors.black87
                              : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: 'Last 4 or 6 digits',
                    hintText: 'e.g., 1234 or 123456',
                    prefixIcon: const Icon(Icons.pin),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _controller.text = widget.account.lastDigits ?? '';
                            _isEditing = false;
                          });
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final text = _controller.text.trim();
                          if (text.isEmpty || !(text.length == 4 || text.length == 6)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter last 4 or 6 digits')),
                            );
                            return;
                          }
                          final updated = widget.account.copyWith(lastDigits: text);
                          context.read<AccountCubit>().updateAccount(updated);
                          setState(() => _isEditing = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Saved')),
                          );
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


