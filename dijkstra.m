
function [costs, paths] = dijkstra(Edges, Weight)
    % Process inputs
    n = size(Edges, 1);
    source_ids = (1:n);
    dest_ids = (1:n);

    [E, cost] = adj2edge(Edges, Weight);
    E = E(:,[2 1]);
       
    % Initialize output
    L = length(source_ids);
    M = length(dest_ids);
    costs = zeros(L,M);
    paths = num2cell(NaN(L,M));

    for k = 1:L

        iTable = NaN(n,1);
        minCost = Inf(n,1);            
        isMin = false(n,1);             
        path = num2cell(NaN(n,1));
        I = source_ids(k);            
        minCost(I) = 0;
        iTable(I) = 0;
        isMin(I) = true;
        path(I) = {I};
        

        while any(~isMin(dest_ids))
            
           
            jTable = iTable;
            iTable(I) = NaN;
            nodeIndex = find(E(:,1) == I);        
            for x = 1:length(nodeIndex)
                J = E(nodeIndex(x),2);
                if ~isMin(J)
                    c = cost(I,J);
                    empty = isnan(jTable(J));
                    if empty || (jTable(J) > (jTable(I) + c))      
                        iTable(J) = jTable(I) + c;
                        path{J} = [path{I} J];
                        
                    else
                        iTable(J) = jTable(J);
                    end
                end
            end
            
           
            K = find(~isnan(iTable));
            if isempty(K)
                break
            else
               
                [~,N] = min(iTable(K));
                I = K(N);
                minCost(I) = iTable(I);
                isMin(I) = true;
            end
        end
        
      
        costs(k,:) = minCost(dest_ids);
        paths(k,:) = path(dest_ids);
    end          
end


function [E,C] = adj2edge(Edges, Weight)
    [I,J] = find(Edges);
    E = [I J];
    C = Weight;
end