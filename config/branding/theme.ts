import { ThemeOptions } from "@mui/material/styles";

const ink = "#1B2631";
const steel = "#46627A";
const petrol = "#2F5D62";
const amber = "#E8A33D";

const brandingTheme: ThemeOptions = {
  palette: {
    primary: {
      main: petrol,
      light: "#5A8A8F",
      dark: "#1F4044",
      contrastText: "#FFFFFF",
    },
    secondary: {
      main: steel,
      light: "#6E8799",
      dark: "#2F4657",
      contrastText: "#FFFFFF",
    },
    success: {
      main: "#2E7D5B",
      light: "#5FAE8A",
      dark: "#1E5A41",
      contrastText: "#FFFFFF",
    },
    highlight: {
      main: "#E7EEF0",
    },
    table: {
      main: "#D3DCE1",
    },
    text: {
      primary: "#1F2A33",
      secondary: "#5A6670",
    },
    background: {
      default: "#F4F5F7",
      paper: "#FFFFFF",
    },
    link: {
      main: "#1F5F99",
    },
    action: {
      disabledBackground: "#ECEEF1",
    },
    tooltip: { main: ink },
    chart: { series: [petrol, amber, "#1F5F99"] },
    yellowCustom: {
      main: "#F2C14E",
      light: "#F7D88A",
      dark: "#B98A1E",
      contrastText: "#3B2F12",
    },
    secondaryBlack: {
      main: ink,
    },
    sage: {
      main: "#D3DCE1",
    },
  },
  typography: {
    fontFamily:
      'system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
    fontWeightLight: 300,
    fontWeightRegular: 400,
    fontWeightMedium: 600,
  },
};

export default brandingTheme;
