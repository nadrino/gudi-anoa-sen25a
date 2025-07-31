//  AvgPdg24OscCov.C  -------------------------------------------------------
//  Run, e.g.:
//      root -l -b -q makeAvgPdg20OscPar.C

#include <TFile.h>
#include <TMath.h>
#include <TObjArray.h>
#include <TObjString.h>
#include <TMatrixT.h>
#include <iostream>

void makeOscCovInvertedPdg24(const char* outfile = "oscCovInvertedPdg24.root")
{
    // ------------------------------------------------------------------ //
    // 1. Parameter names
    // ------------------------------------------------------------------ //
    const char* names[] = {
        "PMNS_SIN_SQUARED_12",
        "PMNS_SIN_SQUARED_13",
        "PMNS_SIN_SQUARED_23",
        "PMNS_DELTA_MASS_SQUARED_21",
        "PMNS_DELTA_MASS_SQUARED_32",
        "PMNS_DELTA_CP",
        "PMNS_SIGN_MASS_SQUARED_32"
    };
    constexpr int N = sizeof(names) / sizeof(names[0]);

    auto* nameArray = new TObjArray(N);
    nameArray->SetName("osc_param_names");
    for (int i = 0; i < N; ++i) {
        nameArray->Add(new TObjString(names[i]));
    }

    // ------------------------------------------------------------------ //
    // 2. Define the parameter prior values and uncertainties
    // ------------------------------------------------------------------ //

    // PDG: https://pdg.lbl.gov/2024/listings/rpp2024-list-neutrino-mixing.pdf
    double parVals[N];
    double parSigs[N];

    // PMNS_SIN_SQUARED_12  PDG 2024: 0.307 +0.013/-0.012
    parVals[0] = 0.307;
    parSigs[0] = 0.013;

    // PMNS_SIN_SQUARED_13  PDG 2024: 2.19E-2 +/- 0.07E-2;
    parVals[1] = 2.19E-2;
    parSigs[1] = 0.07E-2;

    // PMNS_SIN_SQUARED_23  PDG 2024: 0.553 +0.016/-0.024  (inverted ordering)
    // PMNS_SIN_SQUARED_23  PDG 2024: 0.558 +0.015/-0.021  (normal ordering)
    parVals[2] = 0.553;  // inverted
    parSigs[2] = 0.024;  // inverted
    // parVals[2] = 0.558;  // normal
    // parSigs[2] = 0.021;  // normal
    // parVals[2] = 0.556; // average of normal and inverted
    // parSigs[2] = 0.027; // cover full range around average

    // PMNS_DELTA_MASS_SQUARED_21  PDG 2024: 7.53E-5 +/- 0.18E-5
    parVals[3] = 7.53E-5;
    parSigs[3] = 0.18E-5;

    // PMNS_DELTA_MASS_SQUARED_32 should be free in any fit.
    //
    // PMNS_DELTA_MASS_SQUARED_32  PDG 2024: -2.529E-3 +/- 0.029E-3 (inverted)
    // PMNS_DELTA_MASS_SQUARED_32  PDG 2024:  2.455E-3 +/- 0.028E-3 (normal)
    parVals[4] = 2.529E-3; // Inverted
    parSigs[4] = 0.029E-3; // Inverted
    // parVals[4] = 2.445E-3; // Normal
    // parVals[4] = 0.028E-3; // Normal
    // parVals[4] = 2.487E-3; // Average
    // parSigs[4] = 0.113E-3; // Average

    // PMNS_DELTA_CP PDG 2024: 1.19 +/- 0.22
    parSigs[5] = 1.19;
    parSigs[5] = 0.22;

    // PMNS_SIGN_MASS_SQUARED_32  PDG 2024 prefers inverted
    parVals[6] = 0.5;
    parSigs[6] = 10.0;  // Mostly unconstrained


    // ------------------------------------------------------------------ //
    // 3. Create the covariance matrix and prior vector
    // ------------------------------------------------------------------ //
    auto* cov = new TMatrixT<double>(N, N);
    cov->Zero();
    for (int i = 0; i < N; ++i){
        (*cov)(i, i) = parSigs[i]*parSigs[i];
    }
    auto* prior = new TVectorT<double>(N,parVals);

    // ------------------------------------------------------------------ //
    // 4. Write to file
    // ------------------------------------------------------------------ //
    TFile f(outfile, "RECREATE");

    //  Write the names array as ONE key only:
    //     kSingleKey = do NOT write the six sub-objects as individual keys
    nameArray->Write("osc_param_names", TObject::kSingleKey);

    // Write the priors
    f.WriteObject(prior, "osc_param_priors");

    // Write the matrix
    f.WriteObject(cov, "osc_param_cov");

    f.Close();

    std::cout << "Wrote " << outfile << " with:" << std::endl
              << "  • osc_param_names (TObjArray, single key)"  << std::endl
              << "  • osc_param_priors (TVectorT<double>)"  << std::endl
              << "  • osc_param_cov   (TMatrixT<double>)" << std::endl;
}
