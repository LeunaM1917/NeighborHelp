class ServiceProposal {
  ServiceProposal(this.id, Map<String, dynamic> data)
    : providerId = data['providerId'] as String? ?? '',
      providerName = data['providerName'] as String? ?? 'Provider',
      serviceTitle = data['serviceTitle'] as String? ?? '',
      category = data['category'] as String? ?? '',
      description = data['description'] as String? ?? '',
      qualificationName = data['qualificationName'] as String? ?? '',
      certificationEntryId = data['certificationEntryId'] as String? ?? '',
      status = data['status'] as String? ?? 'Pending',
      reviewNotes = data['reviewNotes'] as String? ?? '',
      draftServiceId = data['draftServiceId'] as String? ?? '';
  final String id,
      providerId,
      providerName,
      serviceTitle,
      category,
      description,
      qualificationName,
      certificationEntryId,
      status,
      reviewNotes,
      draftServiceId;
}
