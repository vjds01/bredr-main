const REQUESTS = 'clinicVerificationRequests';
const CLINIC_DIRECTORY = {
  breedr_demo: {
    name: 'Breedr Demo Veterinary Clinic',
    emailProperty: 'CLINIC_EMAIL_BREEDR_DEMO',
    demo: true,
  },
  cabuyao_animal_clinic: {
    name: 'Cabuyao Animal Clinic',
    emailProperty: 'CLINIC_EMAIL_CABUYAO_ANIMAL_CLINIC',
  },
  sitio_beterinaryo_cabuyao: {
    name: 'Sitio Beterinaryo',
    emailProperty: 'CLINIC_EMAIL_SITIO_BETERINARYO',
  },
};

// Run this once from the Apps Script editor after copying the manifest or
// changing the linked Google Cloud project. It prompts the deploying account
// to authorize external requests, email sending, and Firestore access.
function authorizeBreedrServices() {
  UrlFetchApp.fetch('https://www.googleapis.com/discovery/v1/apis', {
    muteHttpExceptions: true,
  });
  MailApp.getRemainingDailyQuota();
  ScriptApp.getOAuthToken();
  return 'Breedr services authorized';
}

function doPost(e) {
  try {
    const contentType = e && e.postData ? String(e.postData.type || '') : '';
    const body = contentType.indexOf('application/json') >= 0
      ? JSON.parse(e.postData.contents || '{}')
      : (e ? e.parameter : {});
    if (body.action === 'createAndDispatch') return json_(createAndDispatch_(body));
    if (body.action === 'dispatch') return json_(dispatch_(body));
    if (body.action === 'decision') return decision_(body);
    return json_({ok: false, error: 'Unsupported action'}, 400);
  } catch (error) {
    return json_({ok: false, error: String(error)}, 500);
  }
}

function createAndDispatch_(body) {
  const uid = verifyFirebaseToken_(String(body.idToken || ''));
  const petId = cleanId_(body.petId);
  const recordId = String(body.recordId || '');
  const pet = readDoc_('pets', petId);
  if (pet.data.ownerId !== uid) throw new Error('Only the pet owner can request confirmation.');
  const records = Array.isArray(pet.data.healthRecords) ? pet.data.healthRecords : [];
  const recordIndex = records.findIndex(item => String(item.recordId || '') === recordId);
  const record = recordIndex < 0 ? null : records[recordIndex];
  if (!record) throw new Error('The selected health record no longer exists.');
  if (record.clinicConsentGranted !== true) throw new Error('Clinic consent was not granted.');
  if (record.verificationStatus === 'verified') throw new Error('This record is already verified.');

  const clinic = resolveClinic_(record);
  if (!clinic) throw new Error('The selected clinic does not have email verification configured.');
  const recipient = requiredProperty_(clinic.emailProperty);

  // A mobile client may lose the redirected Apps Script response after this
  // request has already completed. Reusing the current request makes retries
  // safe and prevents duplicate clinic emails.
  const existingRequestId = String(record.verificationRequestId || '');
  if (record.verificationStatus === 'awaiting_clinic_confirmation' && existingRequestId) {
    const existing = readDoc_(REQUESTS, cleanId_(existingRequestId));
    const sameRecord = existing.data.ownerId === uid &&
      String(existing.data.petId || '') === petId &&
      String(existing.data.recordId || '') === recordId;
    if (sameRecord && existing.data.status === 'awaiting_clinic_confirmation') {
      if (existing.data.dispatchStatus !== 'sent') {
        dispatch_({requestId: existingRequestId, idToken: body.idToken});
      }
      return {ok: true, requestId: existingRequestId, reused: true};
    }
  }

  const requestId = Utilities.getUuid().replace(/-/g, '');
  patchDoc_(REQUESTS, requestId, {
    requestId: requestId,
    petId: petId,
    petName: pet.data.name || 'Pet',
    recordId: recordId,
    ownerId: uid,
    clinicId: clinic.id,
    clinicName: clinic.name,
    clinicEmail: recipient,
    deliveryEmail: recipient,
    testMode: clinic.demo === true,
    status: 'awaiting_clinic_confirmation',
    dispatchStatus: 'queued',
    recordSnapshot: record,
    consentGranted: true,
    consentGrantedAt: new Date(),
    createdAt: new Date(),
    expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
  });
  records[recordIndex] = Object.assign({}, record, {
    verificationRequestId: requestId,
    verificationStatus: 'awaiting_clinic_confirmation',
    verificationRequestedAt: new Date(),
  });
  patchDoc_('pets', petId, {
    healthRecords: records,
    updatedAt: new Date(),
  });
  dispatch_({requestId: requestId, idToken: body.idToken});
  return {ok: true, requestId: requestId};
}

function doGet(e) {
  try {
    const requestId = cleanId_(e.parameter.request);
    const token = String(e.parameter.token || '');
    const request = readDoc_(REQUESTS, requestId);
    const error = validateLink_(request, token);
    if (error) return page_('Clinic verification', `<p>${escape_(error)}</p>`);
    const snapshot = request.data.recordSnapshot || {};
    return page_('Review pet health record', `
      <h1>Review pet health record</h1>
      <p><strong>Pet:</strong> ${escape_(request.data.petName || '')}</p>
      <p><strong>Clinic:</strong> ${escape_(request.data.clinicName || '')}</p>
      <p><strong>Record:</strong> ${escape_(snapshot.otherType || snapshot.type || '')}</p>
      <p><strong>Date issued:</strong> ${escape_(snapshot.dateIssued || '')}</p>
      <p><strong>Veterinarian:</strong> ${escape_(snapshot.veterinarian || '')}</p>
      <p><a href="${escapeAttribute_(snapshot.fileUrl || '')}" target="_blank" rel="noopener">View submitted document</a></p>
      <p class="notice">Please compare the document with your clinic records. Selecting an action below requires one deliberate confirmation.</p>
      ${decisionForm_(requestId, token, 'confirmed', 'Confirm Record', 'confirm')}
      ${decisionForm_(requestId, token, 'declined', 'Record Not Found / Decline', 'decline')}
    `);
  } catch (error) {
    return page_('Clinic verification', `<p>Unable to open request: ${escape_(String(error))}</p>`);
  }
}

function dispatch_(body) {
  const requestId = cleanId_(body.requestId);
  const uid = verifyFirebaseToken_(String(body.idToken || ''));
  const request = readDoc_(REQUESTS, requestId);
  if (request.data.ownerId !== uid) throw new Error('Request owner does not match.');
  if (request.data.status !== 'awaiting_clinic_confirmation') throw new Error('Request is not pending.');

  const rawToken = Utilities.base64EncodeWebSafe(
    Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256,
      Utilities.newBlob(Utilities.getUuid() + Utilities.getUuid()).getBytes()),
  ).replace(/=+$/, '');
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  patchDoc_(REQUESTS, requestId, {
    tokenDigest: digest_(rawToken),
    expiresAt: expiresAt,
    dispatchStatus: 'sent',
    sentAt: new Date(),
  });

  const recipient = String(request.data.deliveryEmail || '');
  if (!recipient) throw new Error('No verification email recipient configured.');
  const url = `${publicWebAppUrl_()}?request=${encodeURIComponent(requestId)}&token=${encodeURIComponent(rawToken)}`;
  MailApp.sendEmail({
    to: recipient,
    name: 'Breedr Health Verification',
    subject: `Breedr clinic confirmation: ${request.data.petName}`,
    htmlBody: `
      <p>A Breedr owner submitted a health record naming <strong>${escape_(request.data.clinicName)}</strong>.</p>
      <p><a href="${url}">Open the secure review page</a></p>
      <div style="margin:16px 0;padding:12px 14px;background:#fff4e5;border:1px solid #e7a23b;border-radius:8px;color:#5f4300;">
        <strong>Using multiple Google accounts?</strong><br>
        Google Apps Script may not open correctly when several Google accounts are signed in. If the page says the file cannot be opened, copy this link and open it in an Incognito or private-browsing window.
      </div>
      <p style="word-break:break-all;font-size:12px;color:#555;">${escape_(url)}</p>
      <p>This single-use link expires in seven days. Opening it alone will not approve the record.</p>
    `,
  });
  return {ok: true};
}

function publicWebAppUrl_() {
  const configured = PropertiesService.getScriptProperties()
    .getProperty('PUBLIC_WEB_APP_URL');
  const serviceUrl = String(configured || ScriptApp.getService().getUrl() || '')
    .trim();
  if (!serviceUrl) throw new Error('The public web-app URL is not configured.');

  // A URL copied while several Google accounts are signed in can contain an
  // account-slot segment such as /macros/u/3/s/. Clinic review links are
  // public, so they must use the account-independent /macros/s/ route.
  return serviceUrl
    .replace(/\/macros\/u\/\d+\/s\//, '/macros/s/')
    .replace(/\/$/, '');
}

function resolveClinic_(record) {
  const requestedId = String(record.clinicId || '').trim();
  let id = requestedId;
  if (!id) {
    const legacyName = String(record.clinic || '').trim().toLowerCase();
    if (legacyName === 'breedr demo veterinary clinic') id = 'breedr_demo';
    if (legacyName === 'cabuyao animal clinic') id = 'cabuyao_animal_clinic';
    if (legacyName === 'sitio beterinaryo' || legacyName === 'sitio beterinaryo cabuyao' || legacyName === 'silo veterinary cabuyao') {
      id = 'sitio_beterinaryo_cabuyao';
    }
  }
  const clinic = CLINIC_DIRECTORY[id];
  return clinic ? Object.assign({id: id}, clinic) : null;
}

function decision_(body) {
  const requestId = cleanId_(body.requestId);
  const token = String(body.token || '');
  const decision = String(body.decision || '');
  if (!['confirmed', 'declined'].includes(decision)) throw new Error('Invalid decision.');
  const request = readDoc_(REQUESTS, requestId);
  const error = validateLink_(request, token);
  if (error) return page_('Clinic verification', `<p>${escape_(error)}</p>`);

  const pet = readDoc_('pets', request.data.petId);
  const records = Array.isArray(pet.data.healthRecords) ? pet.data.healthRecords : [];
  const index = records.findIndex(r => String(r.recordId || '') === String(request.data.recordId || ''));
  if (index < 0) throw new Error('The selected health record no longer exists.');
  const currentRecord = records[index];
  const snapshot = request.data.recordSnapshot || {};
  const latestRequestId = String(currentRecord.verificationRequestId || '');
  const recordChanged = ['type', 'otherType', 'dateIssued', 'fileUrl', 'veterinarian', 'clinic']
    .some(key => String(currentRecord[key] || '') !== String(snapshot[key] || ''));
  if ((latestRequestId && latestRequestId !== requestId) || recordChanged) {
    patchDoc_(REQUESTS, requestId, {
      status: 'superseded',
      response: 'superseded',
      processedAt: new Date(),
      tokenDigest: '',
    }, request.updateTime);
    return page_('Request replaced', '<h1>This request is no longer current</h1><p>The owner edited this health record and a new clinic confirmation is required.</p>');
  }
  records[index] = Object.assign({}, records[index], {
    verificationStatus: decision === 'confirmed' ? 'verified' : 'rejected',
    verificationSource: 'clinic_email',
    verificationRequestId: requestId,
    verifiedAt: new Date(),
    verifiedByName: request.data.clinicName || 'Veterinary clinic',
  });
  const verifiedCount = records.filter(r => r.verificationStatus === 'verified').length;

  // Claim the request first with an update-time precondition. A reused or
  // concurrently submitted token cannot process a second decision.
  patchDoc_(REQUESTS, requestId, {
    status: decision,
    response: decision,
    processedAt: new Date(),
    tokenDigest: '',
    audit: {
      clinic: request.data.clinicName || '',
      response: decision,
      recordId: request.data.recordId,
      userAgent: String(body.userAgent || ''),
    },
  }, request.updateTime);
  patchDoc_('pets', request.data.petId, {
    healthRecords: records,
    vetVerified: verifiedCount > 0,
    verifiedHealthRecordCount: verifiedCount,
    updatedAt: new Date(),
  });
  createDoc_('notifications', {
    recipientId: request.data.ownerId,
    actorId: 'clinic_email',
    petId: request.data.petId,
    petName: request.data.petName,
    type: decision === 'confirmed' ? 'health_record_verified' : 'health_record_rejected',
    purpose: 'health',
    title: decision === 'confirmed' ? 'Health record verified' : 'Health record declined',
    message: decision === 'confirmed'
      ? `${request.data.clinicName} confirmed the submitted health record.`
      : `${request.data.clinicName} could not confirm the submitted health record.`,
    isRead: false,
    createdAt: new Date(),
  });
  return page_('Response recorded', '<h1>Thank you</h1><p>Your response has been recorded. This link can no longer be used.</p>');
}

function validateLink_(request, token) {
  if (request.data.status !== 'awaiting_clinic_confirmation') return 'This request has already been processed.';
  const expires = request.data.expiresAt instanceof Date ? request.data.expiresAt : new Date(request.data.expiresAt);
  if (!expires || expires.getTime() < Date.now()) return 'This verification link has expired.';
  if (!token || digest_(token) !== request.data.tokenDigest) return 'This verification link is invalid.';
  return '';
}

function verifyFirebaseToken_(idToken) {
  const apiKey = requiredProperty_('FIREBASE_WEB_API_KEY');
  const response = UrlFetchApp.fetch(`https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(apiKey)}`, {
    method: 'post', contentType: 'application/json', payload: JSON.stringify({idToken}), muteHttpExceptions: true,
  });
  if (response.getResponseCode() !== 200) throw new Error('Firebase sign-in could not be verified.');
  const users = JSON.parse(response.getContentText()).users || [];
  if (!users.length) throw new Error('Firebase user not found.');
  return users[0].localId;
}

function firestoreUrl_(collection, id) {
  return `https://firestore.googleapis.com/v1/projects/${requiredProperty_('FIREBASE_PROJECT_ID')}/databases/(default)/documents/${collection}/${id}`;
}
function readDoc_(collection, id) {
  const response = authorizedFetch_(firestoreUrl_(collection, cleanId_(id)), {method: 'get'});
  const raw = JSON.parse(response.getContentText());
  return {data: fromFsMap_(raw.fields || {}), updateTime: raw.updateTime};
}
function patchDoc_(collection, id, data, updateTime) {
  const fields = toFsMap_(data);
  const masks = Object.keys(fields).map(k => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join('&');
  const precondition = updateTime ? `&currentDocument.updateTime=${encodeURIComponent(updateTime)}` : '';
  authorizedFetch_(`${firestoreUrl_(collection, cleanId_(id))}?${masks}${precondition}`, {
    method: 'patch', contentType: 'application/json', payload: JSON.stringify({fields}),
  });
}
function createDoc_(collection, data) {
  const id = Utilities.getUuid().replace(/-/g, '');
  patchDoc_(collection, id, Object.assign({notificationId: id}, data));
}
function authorizedFetch_(url, options) {
  options = options || {};
  options.headers = Object.assign({}, options.headers, {Authorization: `Bearer ${ScriptApp.getOAuthToken()}`});
  options.muteHttpExceptions = true;
  const response = UrlFetchApp.fetch(url, options);
  if (response.getResponseCode() < 200 || response.getResponseCode() >= 300) throw new Error(response.getContentText());
  return response;
}

function toFsMap_(map) { const out = {}; Object.keys(map).forEach(k => out[k] = toFs_(map[k])); return out; }
function toFs_(v) {
  if (v instanceof Date) return {timestampValue: v.toISOString()};
  if (Array.isArray(v)) return {arrayValue: {values: v.map(toFs_)}};
  if (v !== null && typeof v === 'object') return {mapValue: {fields: toFsMap_(v)}};
  if (typeof v === 'boolean') return {booleanValue: v};
  if (typeof v === 'number') return Number.isInteger(v) ? {integerValue: String(v)} : {doubleValue: v};
  if (v === null) return {nullValue: null};
  return {stringValue: String(v)};
}
function fromFsMap_(fields) { const out = {}; Object.keys(fields).forEach(k => out[k] = fromFs_(fields[k])); return out; }
function fromFs_(v) {
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('timestampValue' in v) return new Date(v.timestampValue);
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(fromFs_);
  if ('mapValue' in v) return fromFsMap_(v.mapValue.fields || {});
  return null;
}

function requiredProperty_(name) { const value = PropertiesService.getScriptProperties().getProperty(name); if (!value) throw new Error(`${name} is not configured.`); return value; }
function cleanId_(value) { value = String(value || ''); if (!/^[A-Za-z0-9_-]+$/.test(value)) throw new Error('Invalid identifier.'); return value; }
function digest_(value) { return Utilities.base64EncodeWebSafe(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, value)).replace(/=+$/, ''); }
function json_(value) { return ContentService.createTextOutput(JSON.stringify(value)).setMimeType(ContentService.MimeType.JSON); }
function escape_(value) { return String(value || '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
function escapeAttribute_(value) { return escape_(value); }
function decisionForm_(requestId, token, decision, label, css) {
  const actionUrl = escapeAttribute_(publicWebAppUrl_());
  return `<form method="post" action="${actionUrl}" target="_top" onsubmit="document.getElementById('ua-${decision}').value=navigator.userAgent;return confirm('Submit this decision? It cannot be changed.');"><input type="hidden" name="action" value="decision"><input type="hidden" name="requestId" value="${escapeAttribute_(requestId)}"><input type="hidden" name="token" value="${escapeAttribute_(token)}"><input type="hidden" name="decision" value="${decision}"><input type="hidden" name="userAgent" id="ua-${decision}"><button type="submit" class="${css}">${label}</button></form>`;
}
function page_(title, body) { return HtmlService.createHtmlOutput(`<!doctype html><meta name="viewport" content="width=device-width"><title>${escape_(title)}</title><style>body{font:16px Arial;max-width:680px;margin:40px auto;padding:24px;color:#24202a}h1{color:#ff5067}.notice{background:#fff0f5;padding:14px;border-radius:10px}button{width:100%;padding:14px;margin:7px 0;border:0;border-radius:10px;font-weight:bold;cursor:pointer}.confirm{background:#0756b5;color:white}.decline{background:#ffe2e7;color:#a3293c}a{color:#0756b5}</style>${body}`); }
