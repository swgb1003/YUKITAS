import * as admin from "firebase-admin";

admin.initializeApp();

export { analyzeSnowPhoto } from "./analyzeSnowPhoto";
export { notifyOnRequestChange, notifyWorkersOnNewRequest } from "./notifications";
