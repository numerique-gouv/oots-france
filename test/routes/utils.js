const leveErreur = (e) => Promise.reject(e.response?.data || e);

module.exports = { leveErreur };
