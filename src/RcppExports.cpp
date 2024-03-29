// Generated by using Rcpp::compileAttributes() -> do not edit by hand
// Generator token: 10BE3573-1514-4C36-9D1C-5A225CD40393

#include <Rcpp.h>

using namespace Rcpp;

#ifdef RCPP_USE_GLOBAL_ROSTREAM
Rcpp::Rostream<true>&  Rcpp::Rcout = Rcpp::Rcpp_cout_get();
Rcpp::Rostream<false>& Rcpp::Rcerr = Rcpp::Rcpp_cerr_get();
#endif

// PairwiseD
List PairwiseD(const NumericMatrix& cum, const NumericVector& b, const NumericVector& a);
RcppExport SEXP _GUniFrac_PairwiseD(SEXP cumSEXP, SEXP bSEXP, SEXP aSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< const NumericMatrix& >::type cum(cumSEXP);
    Rcpp::traits::input_parameter< const NumericVector& >::type b(bSEXP);
    Rcpp::traits::input_parameter< const NumericVector& >::type a(aSEXP);
    rcpp_result_gen = Rcpp::wrap(PairwiseD(cum, b, a));
    return rcpp_result_gen;
END_RCPP
}
// gmpr
NumericVector gmpr(IntegerMatrix x, int min_ct, int intersect_no);
RcppExport SEXP _GUniFrac_gmpr(SEXP xSEXP, SEXP min_ctSEXP, SEXP intersect_noSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< IntegerMatrix >::type x(xSEXP);
    Rcpp::traits::input_parameter< int >::type min_ct(min_ctSEXP);
    Rcpp::traits::input_parameter< int >::type intersect_no(intersect_noSEXP);
    rcpp_result_gen = Rcpp::wrap(gmpr(x, min_ct, intersect_no));
    return rcpp_result_gen;
END_RCPP
}

static const R_CallMethodDef CallEntries[] = {
    {"_GUniFrac_PairwiseD", (DL_FUNC) &_GUniFrac_PairwiseD, 3},
    {"_GUniFrac_gmpr", (DL_FUNC) &_GUniFrac_gmpr, 3},
    {NULL, NULL, 0}
};

RcppExport void R_init_GUniFrac(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
