import { BrandingConfig } from "@/types/branding";

const branding: BrandingConfig = {
  productName: "Feasibility Tool",
  productLongName: "Feasibility Tool",
  description: "Check whether enough suitable patients exist before you start a study",
  organisationName: "Example Organisation",
  logoAlt: "Feasibility Tool logo",
  loginTitle: ["Feasibility", "Tool"],
  loginHeadline: ["Ask the question.", "Count the cohort."],
  loginSubheadline: "Find out how many people match, across every collection, before you commit.",
  copyrightHolder: "Example Organisation",
  hdrukChromeInStandalone: false,
  links: {
    organisation: "https://example.org",
  },
  legal: {
    termsAndConditions: {
      title: "Terms and conditions",
      lastUpdated: "Never",
    },
    privacyPolicy: {
      title: "Privacy policy",
      lastUpdated: "Never",
    },
  },
};

export default branding;
