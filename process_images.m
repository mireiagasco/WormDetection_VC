function process_images(carpeta_imatges, fitxer_resultats)
    close all;

    % Define the input parser
    p = inputParser;
    addRequired(p, 'carpeta_imatges', @ischar);
    addRequired(p, 'fitxer_resultats', @ischar);
    parse(p, carpeta_imatges, fitxer_resultats);

    % Get the parsed inputs
    carpeta_imatges = p.Results.carpeta_imatges;
    fitxer_resultats = p.Results.fitxer_resultats;

    % Llegir llista d'imatges a partir de la carpeta
    imatges = dir(fullfile(carpeta_imatges, '*.tif'));
    total_imatges = length(imatges);

    % Creem el directori dels resultats si no existeix i sino el buidem
    results_folder = 'results';
    if exist(results_folder, 'dir')
        delete(fullfile(results_folder, '*'));
    else
        mkdir(results_folder);
    end

    % Arrays amb els resultats
    image_numbers = (1:total_imatges)';
    cuc_cont = zeros(total_imatges, 1);
    viu_cont = zeros(total_imatges, 1);
    mort_cont = zeros(total_imatges, 1);
    tipus_cont = cell(total_imatges, 1);

    % Llegim el csv
    dades_cucs = readtable(fitxer_resultats);
    cucs_morts_csv = dades_cucs{:, 2};
    cucs_vius_csv = dades_cucs{:, 3};

    % Bucle per processar cada imatge
    for idx = 1:total_imatges
        % Llegir imatge
        imatge_path = fullfile(carpeta_imatges, imatges(idx).name);
        imatge = imread(imatge_path);

        % Preprocessament de la imatge
        img_adapteq = adapthisteq(imatge);

        % Binarització
        threshold_bin = 0.22;
        imatge_binaria_processada = imbinarize(img_adapteq, threshold_bin);

        % Anàlisi de contorns
        [contorns, L] = bwboundaries(imatge_binaria_processada);
        stats = regionprops(L, "Circularity", "Centroid");

        % Comptadors de cucs vius i morts
        cuc = 0;
        vius = 0;
        morts = 0;

        % Mida mínima de contorn acceptable
        area_minima = 50;

        % Crear una nova figura per cada imatge
        figure;
        imshow(imatge);
        hold on;

        % Dibuixar els contorns a la imatge original amb l'etiqueta "CUC"
        for k = 1:length(contorns)
            contorn = contorns{k};

            % Calcular l'àrea i el perimetre del contorn
            area_contorn = polyarea(contorn(:, 2), contorn(:, 1));
            perimetre_contorn = sum(sqrt(sum(diff(contorn) .^ 2, 2)));

            % Comprovar si l'àrea del contorn és superior al valor de llindar
            if ((area_contorn >= area_minima) && area_contorn < 5000)

                [distancia_max_superior, distancia_max_inferior] = calcul_distancies_regressio(contorn);
                amplada = abs(distancia_max_inferior) + abs(distancia_max_superior);
                threshold_amplada = 11;

                if amplada < threshold_amplada
                    estat = 'Mort';
                    color_label = 'red';
                    morts = morts + 1;
                else
                    estat = 'Viu';
                    color_label = 'green';
                    vius = vius + 1;
                end

                % Afegir etiqueta "Viu" o "Mort" a la imatge
                centroid = mean(contorn);
                text(centroid(2), centroid(1), estat, 'Color', color_label, 'FontSize', 12, 'HorizontalAlignment', 'center');

                cuc = cuc + 1;

                % Dibuixar el contorn del cuc
                plot(contorn(:, 2), contorn(:, 1), 'Color', 'Red', 'LineWidth', 2);
            end
        end

        % Desem els comptadors
        cuc_cont(idx) = cuc;
        viu_cont(idx) = vius;
        mort_cont(idx) = morts;

        if vius > morts
            tipus_cont{idx} = 'alive';
        else
            tipus_cont{idx} = 'dead';
        end

        % Mostrar el nombre total de cucs vius i morts a la imatge
        total_text = sprintf('Total Cuc(s): %d\nViu(s): %d\nMort(s): %d', cuc, vius, morts);
        annotation('textbox', [0.8, 0.8, 0.1, 0.1], 'String', total_text, 'Color', 'black', 'FontSize', 12, 'BackgroundColor', 'white');

        title(['Detecció de cucs - Imatge ', num2str(idx)]);
        hold off;

        % Desem la imatge actual
        fig_nom = fullfile(results_folder, sprintf('image_%d.png', idx));
        saveas(gcf, fig_nom);

        % Obtenim els valors esperats
        morts_esperats = cucs_morts_csv(idx);
        vius_esperats = cucs_vius_csv(idx);
        total_esperat = morts_esperats + vius_esperats;

        % Mostrem la comparació
        disp(['Imatge ', num2str(idx), ':']);
        disp(['  Recompte Cucs: ', num2str(cuc), '/', num2str(total_esperat)]);
        disp(['  Cucs Vius: ', num2str(vius), '/', num2str(vius_esperats)]);
        disp(['  Cucs Morts: ', num2str(morts), '/', num2str(morts_esperats)]);
        disp(' ');
    end

    % Creem una taula per desar els resultats
    results_table = table(image_numbers, cuc_cont, viu_cont, mort_cont, tipus_cont, 'VariableNames', {'Imatge', 'NumeroCucs', 'CucsVius', 'CucsMorts', 'Classificació'});

    % Escribim la taula al fitxer
    writetable(results_table, 'results/resultat.xlsx');

    % Obtenim les etiquetes de la primera columna
    etiquetes = dades_cucs.File_Status;
    % Split the labels to extract the 'alive' or 'dead' part
    etiquetes_parts = split(etiquetes, ',');
    etiqueta_estat = etiquetes_parts(:, 2); % Extract the 'alive' or 'dead' part

    % Comparem l'estat amb el resultat
    prediccions_correctes = strcmp(tipus_cont, etiqueta_estat);

    % Calculem el total
    total_prediccions = numel(prediccions_correctes);
    disp(['Imatges classificades correctament: ', num2str(sum(prediccions_correctes)), '/', num2str(total_prediccions)]);
end

function [distancia_max_superior, distancia_max_inferior] = calcul_distancies_regressio(punts)
    % Calcular la regressió lineal
    coeficients = polyfit(punts(:, 1), punts(:, 2), 1);
    pendent = coeficients(1);
    intercept = coeficients(2);

    % Calculate the signed distances
    distancies_signe = (punts(:, 2) - (pendent * punts(:, 1) + intercept)) / sqrt(pendent ^ 2 + 1);

    % Find the points with maximum positive and negative distances
    [distancia_max_superior, ~] = max(distancies_signe);
    [distancia_max_inferior, ~] = min(distancies_signe);
end
