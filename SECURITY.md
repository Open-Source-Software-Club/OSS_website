# Security Policy

The Open Source Software Club at Sai Vidya Institute of Technology (SVIT) takes the security of our website, infrastructure, and user data seriously. This document outlines our policy for reporting and resolving security vulnerabilities.

---

## 🛡️ Supported Versions

The website is deployed continuously from `main`, and nothing has been released
or tagged yet, so `main` is the only supported line. When versioned releases
begin, this table will list the release lines that receive security fixes.

| Version / Branch | Supported | Notes |
|:---|:---:|:---|
| `main` | :white_check_mark: | The only supported line; fixes land here first |
| Anything else (forks, old commits) | :x: | Update to the latest `main` |

---

## 🚨 Reporting a Vulnerability

> [!CAUTION]
> **DO NOT file public GitHub issues, discussions, or pull requests for suspected security vulnerabilities.** Disclosing vulnerabilities publicly exposes user data and services before a fix can be prepared and deployed.

### Preferred Method: GitHub Private Vulnerability Reporting
1. Navigate to the repository's [Security Advisories](https://github.com/Open-Source-Software-Club/OSS_website/security/advisories) page.
2. Click **Report a vulnerability** to open a private advisory draft.
3. This allows secure, encrypted collaboration directly between you and the repository maintainers.

### If you cannot use GitHub Security Advisories
Private vulnerability reporting is the only channel the maintainers monitor for
security reports. If you cannot use it, open a **public** issue that says only
*"I have a security report and need a private channel"* — no details — or
mention one of the security owners listed in [MAINTAINERS.md](MAINTAINERS.md),
and a maintainer will arrange a private conversation.

---

## 📋 What Information to Include

To help us investigate, triage, and remediate the issue quickly, please provide as much detail as possible in your report:

1. **Vulnerability Type:** (e.g., Cross-Site Scripting (XSS), SQL Injection / Supabase RLS bypass, Broken Authentication, CSRF, Insecure Direct Object References (IDOR), Information Disclosure).
2. **Affected Component:** Specific file paths, API endpoints, Server Actions, or pages (e.g., `src/app/api/auth/...` or `src/lib/supabase/server.ts`).
3. **Step-by-Step Reproduction:** Exact steps required to reproduce the issue.
4. **Proof of Concept (PoC):** Sample payload, screenshot, or sanitized HTTP request/response log.
5. **Impact Assessment:** An explanation of what an attacker could achieve if exploiting this vulnerability (e.g., privilege escalation, unauthorized database read/write, credential leakage).
6. **Suggested Fix (Optional):** If you have identified a code-level patch or configuration fix, feel free to share it.

---

## ⏱️ Response Timelines

Our maintainer team adheres to the following coordinated response targets:

| Stage | Target Response Window | Description |
|:---|:---:|:---|
| **Initial Acknowledgement** | Within **48 hours** | We confirm receipt of your report and assign a maintainer to investigate. |
| **Triage & Severity Assessment** | Within **5 business days** | We evaluate reproducibility, determine CVSS severity, and notify you of the findings. |
| **Patch & Remediation** | **7 – 30 calendar days** | Critical / High severity: within **7 to 14 days**.<br>Medium / Low severity: within **30 days**. |
| **Public Disclosure & Advisory** | Coordinated | Published after the patch is deployed to production, crediting the reporter. |

---

## 🤝 Responsible Disclosure & Safe Harbor

We believe in responsible, coordinated vulnerability disclosure. If you conduct security research in accordance with the following principles, the OSS Club will not pursue civil or criminal legal action against you:

### Research Guidelines:
- **Do no harm:** Avoid actions that degrade system availability, cause denial of service (DoS), or alter and corrupt production data.
- **Respect privacy:** If you encounter sensitive student, faculty, or user data, stop testing immediately, do not download or store the data, and report the issue at once.
- **Confidentiality:** Allow our maintainers a reasonable time frame (up to 90 days from report, or until mutually agreed upon) to address the vulnerability before discussing it publicly or sharing details with third parties.
- **No extortion:** Do not demand financial compensation or bounties in exchange for reporting vulnerabilities. As a non-profit student club, we do not operate a paid bug bounty program, but we proudly provide public acknowledgment and Hall of Fame recognition.

---

## 🎖️ Recognition & Hall of Fame

We deeply value the time and expertise of security researchers and open-source contributors who help make our platform safer. With your permission, we will happily:

- Credit you in our [CHANGELOG.md](CHANGELOG.md) and official GitHub Security Advisory.
- List your name, handle, and contribution in the **Security Hall of Fame** section on the OSS Club Website.
- Provide a letter of appreciation from the OSS Club and Sai Vidya Institute of Technology faculty mentor upon request.
