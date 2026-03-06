import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/seller_service.dart';
import '../../widgets/marketplace_drawer.dart';

class SellerCenterScreen extends StatefulWidget {
  const SellerCenterScreen({super.key});

  @override
  State<SellerCenterScreen> createState() => _SellerCenterScreenState();
}

class _SellerCenterScreenState extends State<SellerCenterScreen> {
  final SellerService _sellerService = SellerService();
  final _formKey = GlobalKey<FormState>();
  final _merchantName = TextEditingController();
  final _storeName = TextEditingController();
  final _phoneNumber = TextEditingController();
  bool _submitting = false;

  String? _nationalIdUrl;
  String? _commercialRegistrationUrl;
  String? _taxCardUrl;

  @override
  void dispose() {
    _merchantName.dispose();
    _storeName.dispose();
    _phoneNumber.dispose();
    super.dispose();
  }

  Future<String?> _uploadFile({
    required AppUser user,
    required PlatformFile file,
  }) async {
    try {
      return _sellerService.uploadSellerDocument(
        uid: user.uid,
        fileName: file.name,
        bytes: file.bytes!,
      );
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'seller_center.upload_failed'.tr(namedArgs: {'error': '$e'}),
          ),
        ),
      );
      return null;
    }
  }

  Future<void> _pickAndUploadDocument(AppUser user, String documentType) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('seller_center.file_read_failed'.tr())),
      );
      return;
    }

    final url = await _uploadFile(user: user, file: file);
    if (url == null) return;

    setState(() {
      switch (documentType) {
        case 'national_id':
          _nationalIdUrl = url;
          break;
        case 'commercial_registration':
          _commercialRegistrationUrl = url;
          break;
        case 'tax_card':
          _taxCardUrl = url;
          break;
      }
    });
  }

  Future<void> _submitSellerApplication(AppUser user) async {
    if (!_formKey.currentState!.validate()) return;
    if (_nationalIdUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('seller_center.national_id_required'.tr())),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _sellerService.submitSellerRequest(
        user: user,
        merchantName: _merchantName.text.trim(),
        storeName: _storeName.text.trim(),
        phoneNumber: _phoneNumber.text.trim(),
        nationalIdImage: _nationalIdUrl!,
        commercialRegisterImage: _commercialRegistrationUrl,
        taxCardImage: _taxCardUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your seller request has been submitted successfully and is awaiting admin approval.',
          ),
        ),
      );
      Navigator.of(context).pushNamed('/seller/waiting');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'seller_center.submission_failed'.tr(namedArgs: {'error': '$e'}),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildDocumentUploadTile({
    required AppUser user,
    required String title,
    required String type,
    required String? url,
    required bool isRequired,
  }) {
    final isImage = url != null &&
        (url.toLowerCase().contains('.png') ||
            url.toLowerCase().contains('.jpg') ||
            url.toLowerCase().contains('.jpeg') ||
            url.toLowerCase().contains('image'));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.panel(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: ListTile(
        leading: _buildDocumentLeading(url: url, isImage: isImage),
        title: Text(isRequired ? '$title *' : title),
        subtitle: Text(
          url != null
              ? 'seller_center.document_uploaded'.tr()
              : 'seller_center.no_document_selected'.tr(),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.upload_file_outlined),
          onPressed: () => _pickAndUploadDocument(user, type),
        ),
      ),
    );
  }

  Widget _buildDocumentLeading({
    required String? url,
    required bool isImage,
  }) {
    if (url == null) {
      return const Icon(Icons.file_upload_outlined, color: Colors.grey);
    }

    if (!isImage) {
      return const Icon(
        Icons.picture_as_pdf_outlined,
        color: Colors.redAccent,
      );
    }

    return ClipOval(
      child: SizedBox(
        width: 40,
        height: 40,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.panelSoft(context),
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.orange,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _customerRegistrationForm(AppUser user) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.panel(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'seller_center.form.title'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text('seller_center.steps_info'.tr()),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _merchantName,
                  decoration: InputDecoration(
                    labelText: 'seller_center.form.merchant_name'.tr(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'seller_center.field_required'.tr(
                          namedArgs: {
                            'field': 'seller_center.form.merchant_name'.tr(),
                          },
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _storeName,
                  decoration: InputDecoration(
                    labelText: 'seller_center.form.store_name'.tr(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'seller_center.field_required'.tr(
                          namedArgs: {
                            'field': 'seller_center.form.store_name'.tr(),
                          },
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneNumber,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'phone_number'.tr(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'seller_center.field_required'.tr(
                          namedArgs: {'field': 'phone_number'.tr()},
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  enabled: false,
                  initialValue: user.email ?? '',
                  decoration: InputDecoration(
                    labelText: 'seller_center.form.email'.tr(),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'seller_center.required_documents'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildDocumentUploadTile(
                  user: user,
                  title: 'seller_center.form.id_document'.tr(),
                  type: 'national_id',
                  url: _nationalIdUrl,
                  isRequired: true,
                ),
                const SizedBox(height: 4),
                Text(
                  'seller_center.optional_documents'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildDocumentUploadTile(
                  user: user,
                  title: 'seller_center.form.commercial_registration'.tr(),
                  type: 'commercial_registration',
                  url: _commercialRegistrationUrl,
                  isRequired: false,
                ),
                _buildDocumentUploadTile(
                  user: user,
                  title: 'seller_center.form.tax_card'.tr(),
                  type: 'tax_card',
                  url: _taxCardUrl,
                  isRequired: false,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed:
                      _submitting ? null : () => _submitSellerApplication(user),
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    _submitting
                        ? 'seller_center.form.submitting'.tr()
                        : 'seller_center.form.submit_button'.tr(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sellerControl(AppUser user) {
    final approval = user.isApproved
        ? 'seller_center.status.approved'.tr()
        : 'seller_center.status.pending'.tr();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.panel(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border(context)),
            ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  user.isApproved
                      ? Icons.verified_user
                      : Icons.pending_outlined,
                  color: user.isApproved ? Colors.green : Colors.orange,
                ),
                title: Text('seller_center.account_status'.tr()),
                subtitle: Text(approval),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text('seller_center.open_dashboard'.tr()),
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(user.isApproved ? '/seller' : '/seller/waiting'),
              ),
              if (user.isApproved) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pushNamed('/seller'),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: Text(
                          context.locale.languageCode == 'ar'
                              ? 'إدارة المنتجات'
                              : 'Manage products',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.locale.languageCode == 'ar'
                      ? 'من لوحة البائع يمكنك إضافة المنتجات وتعديلها وحذفها.'
                      : 'From the seller dashboard you can add, edit, and delete products.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _customerPendingRequest(AppUser user) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.panel(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border(context)),
            ),
          child: Column(
            children: [
              const Icon(Icons.hourglass_top_outlined, color: AppTheme.primary),
              const SizedBox(height: 10),
              Text(
                'seller.waiting_approval.description'.tr(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/seller/waiting'),
                child: Text('seller.waiting_approval.title'.tr()),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/customer/profile'),
                child: Text('profile.account_status'.tr()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();
    final effectiveRole = auth.isAdmin ? UserRole.admin : user.role;

    return Scaffold(
      backgroundColor: AppTheme.scaffold(context),
      appBar: AppBar(title: Text('seller_center.control.title'.tr())),
      drawer: const MarketplaceDrawer(),
      body: switch (effectiveRole) {
        UserRole.customer => user.sellerRequestStatus == 'pending'
            ? _customerPendingRequest(user)
            : _customerRegistrationForm(user),
        UserRole.seller => _sellerControl(user),
        UserRole.admin => ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.panel(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title:
                      Text('seller_center.control.open_admin_dashboard'.tr()),
                  onTap: () => Navigator.of(context).pushNamed('/admin'),
                ),
              ),
            ],
          ),
        UserRole.supplier => Center(
            child: Text('seller_center.supplier_managed'.tr()),
          ),
        UserRole.guest => const SizedBox.shrink(),
      },
    );
  }
}
