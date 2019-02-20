clear;
close all;


addpath('..')

plotPollsters = true;
max_perc = 40;
numSimulations = 100;

tableout = loadPollsSpainLinux('EncuestasGenerales.xlsx');
tableout(:,end)=[]; % Remove otros

parties = tableout.Properties.VariableNames(5:end);

pollsters = unique(tableout.Encuestador);
pollsters(strcmp(pollsters,'Elecciones'))=[];

dates = datenum(min(tableout.FechaFin):max(tableout.FechaFin));

values=nan(length(dates),length(parties),numSimulations);

for k=1:numSimulations
    if(mod(k,100)==0)
        disp(['Simulation: ' num2str(k)])
    end
    
    slope = nan(length(dates),length(parties),length(pollsters));
    weight = nan(length(dates),length(parties),length(pollsters));
    
    for i=1:length(pollsters)
        pollsIndex = find(strcmp(tableout.Encuestador,'Elecciones') | ...
                      strcmp(tableout.Encuestador,pollsters{i}));
    
        pollsDates = datenum(tableout.FechaFin(pollsIndex));
        pollsSample = tableout.Muestra(pollsIndex);
        pollsValues = table2array(tableout(pollsIndex,5:end))/100;
    
        [pollsDates,order] = sort(pollsDates);
        pollsSample = pollsSample(order);
        pollsValues = pollsValues(order,:);
    
        for l=1:length(parties)
            indexPollsParty = ~isnan(pollsValues(:,l));
            pollsDatesParty = pollsDates(indexPollsParty);
            pollsSampleParty = pollsSample(indexPollsParty);
            pollsValuesParty = pollsValues(indexPollsParty,l);
            error = estimarError(pollsValuesParty, pollsSampleParty, 0.999);
            pollsValuesParty = pollsValuesParty + error.*randn(size(pollsValuesParty));
            
            for j=1:length(pollsDatesParty)-1
                numDays = pollsDatesParty(j+1)-pollsDatesParty(j);
                thisSlope = (pollsValuesParty(j+1) - pollsValuesParty(j))/numDays;
                firstDay = find(dates==pollsDatesParty(j))+1;
                lastDay = find(dates==pollsDatesParty(j+1));
                slope(firstDay:lastDay,l,i) = thisSlope;
                weight(firstDay:lastDay,l,i) = 1./numDays;
            end
        end
    end
    
    values(:,:,k)=cumsum(sum(slope.*weight,3,'omitnan')./sum(weight,3,'omitnan'),'omitnan')*100+table2array(tableout(end,5:end));
end
    
%%
%values(values<0)=0;
%values=values./max(1,sum(values,2)/100);
intencionDeVoto=mean(values,3,'omitnan');
errorGraficos=std(values,[],3)*2;

selection = find(intencionDeVoto(end,:)>=5);

for i=1:height(tableout)
    encuestas(i).fecha = datenum(tableout.FechaFin(i));
    encuestas(i).fechaFin = datenum(tableout.FechaFin(i));
    encuestas(i).resultados = table2array(tableout(i,selection+4));
    encuestas(i).resultados = [encuestas(i).resultados 100-sum(encuestas(i).resultados)];
    encuestas(i).muestra = tableout.Muestra(i);
    encuestas(i).encuestador = tableout.Encuestador(i);
end

parties{end+1} = 'Otros';
intencionDeVoto(:,end+1)=mean(max(0,min(100,100-sum(values(:,selection,:),2,'omitnan'))),3,'omitnan');
errorGraficos(:,end+1)=2*std(max(0,min(100,100-sum(values(:,selection,:),2,'omitnan'))),[],3,'omitnan');

selection(end+1)=length(parties);

[f,p]=plotEstimacionVotoElecciones(intencionDeVoto(:,selection)',errorGraficos(:,selection)',dates,...
    encuestas,parties(:,selection),'Intención de Voto Elecciones Generales',...
    'Promedio de encuestas sobre elecciones al Congreso de los Diputados y estimación de error',...
    'Electograph | Modelo Propio','','Intención de voto (%)',[dates(1) dates(end)],[0 max_perc]);

t=text(max(dates),max_perc+1,['*La zona de sombra y el error indican zona probable al ' ...
    num2str(99.0) '%']);
set(t,'HorizontalAlign','right')
set(t,'FontSize',8)
set(t,'Color',ones(1,3)*0.5)

saveas(f,'IntencionVotoEspaña.png')

%%
if(plotPollsters)
    pollsters = unique([encuestas.encuestador]);
    for j=1:length(pollsters)
        indicesEncuestador = strcmp([encuestas.encuestador],char(pollsters(j))) | ...
            strcmp([encuestas.encuestador],'Elecciones');
        encuestasFiltradas = encuestas(indicesEncuestador);
        if(length(encuestasFiltradas)<2)
            continue;
        end
        indicesFechasEncuestador = zeros(sum(indicesEncuestador),1);
        [fechasEncuestador,ordenEncuestador] = sort([encuestasFiltradas.fecha]);
        for i=1:length(indicesFechasEncuestador)
            indicesFechasEncuestador(i) = find(dates==fechasEncuestador(i));
        end

        f=plotEstimacionVotoElecciones(intencionDeVoto(:,selection)',errorGraficos(:,selection)',dates,...
            [],parties(:,selection),...
            'Intención de Voto Elecciones Generales',...
            ['Comparativa del Promedio de encuestas (línea continua) y ' char(pollsters(j)) ' (línea de puntos)'],...
            'Electograph | Modelo Propio','','Intención de voto (%)',...
            [dates(1) dates(end)],[0 max_perc]);

        resultadosEncuestador = cell2mat({encuestasFiltradas(ordenEncuestador).resultados}');
        hold on
        for i=1:length(parties(selection))
            plot(dates(indicesFechasEncuestador),resultadosEncuestador(:,i),':.',...
                'Color',getPartyColor(parties{selection(i)}),'LineWidth',1,'MarkerSize',8)
        end
        hold off

        saveas(f,['IntencionVotoEspaña-' char(pollsters(j)) '.png'])
    end
end

%%
%%

out.porcentajeVoto=intencionDeVoto(:,selection)';
out.errorGrafico = errorGraficos(:,selection)';
out.partidos=parties(selection);
out.fechas=datestr(dates,'yyyy/mm/dd');

for i=1:length(encuestas)
    valoresEncuesta = encuestas.resultados;
    valoresEncuesta(isnan(valoresEncuesta)) = -1000;
    encuestasOut(i)=struct('inicio',datestr(encuestas(i).fecha,'yyyy/mm/dd'),...
        'fin',datestr(encuestas(i).fechaFin,'yyyy/mm/dd'),...
        'resultados',valoresEncuesta,...
        'muestra',encuestas(i).muestra,...
        'encuestador',encuestas(i).encuestador);
end
out.encuestas=encuestasOut;
out.actualizacion=datestr(now,'dd/mm/yyyy HH:MM:SS');

jsonPromedio = fopen('promedioTendencia.json','w');
fwrite(jsonPromedio,jsonencode(out));
fclose(jsonPromedio);