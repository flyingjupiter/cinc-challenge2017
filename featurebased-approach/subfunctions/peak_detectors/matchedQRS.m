% Matched filtering for QRS detection
%
%
%
function [qrs,ect_qrs] = matchedQRS(signal,templates,qrsref,btype)

THRES = 0.7;  % correlation threshold, relative to priori knowledge on QRS
THRESgof = 0.4; % NMSE threshold
WIN = round(2*length(templates{1}));
qrs = cell(size(templates));
xcors = cell(size(templates));
ect_qrs = [];
%% Find new peaks by cross correlation
for i = 1:length(templates)
    padt = [templates{i}; zeros(length(signal)-length(templates{i}),1)];
    xcor = xcorr(padt,signal)/(norm(padt)*norm(signal));
    xcor = xcor(length(signal):-1:1); xcor = circshift(xcor,[round(length(templates{i})/2) 1]);
    xcor(xcor<0) = 0;
    thresh=nanmedian(THRES*xcor(qrsref));
    [~,qrstmp] = findpeaks(xcor,'MinPeakDistance',round(0.8*WIN),'MinPeakProminence',thresh);
%     qrstmp = sort([qrstmp; qrsref(btype == i)]); % Rescue previously detected abnomallies
%     qrstmp(diff(qrstmp)<WIN) = [];
    qrstmp(qrstmp<length(templates{i})/2|qrstmp>(length(signal)-length(templates{i})/2)) = []; % remove extremities
    segs = arrayfun(@(x) signal(x-floor(length(templates{i})/2):x+floor(length(templates{i})/2)),qrstmp,'UniformOutput',0);
    gof = cellfun(@(x)  1 - sum((x -templates{i}).^2)/sum((templates{i}-mean(templates{i})).^2),segs); % calculates goodness of fit for each beat agains template
    qrstmp = qrstmp(gof>THRESgof);
    qrs{i} = qrstmp;
    xcors{i} = xcor(qrstmp).*gof(gof>THRESgof);
    clear xcortmp qrstmp
end

%% Separate beats by type (avoid double peaks)
%== Removing peaks of low amplitude (likely noise)
% if length(templates) > 1
%     if 0.3*abs(median(signal(qrs{1}))) > abs(median(signal(qrs{2})))
%         qrs(2) = [];
%         templates(2) = [];
%     elseif 0.3*abs(median(signal(qrs{2}))) > abs(median(signal(qrs{1})))
%         qrs{1} = qrs{2};        
%         templates{1} = templates{2};
%         qrs(2) = [];
%         templates(2) = [];
%     end            
% end

%== Highest correlation/gof is kept.
if length(templates) > 1
        % matching closest indices
        if length(qrs{1}) > length(qrs{2})
            qrs1 = qrs{1};
            qrs2 = qrs{2};
        else
            qrs2 = qrs{1};
            qrs1 = qrs{2};
            tmp = xcors{1};
            xcors{1} =xcors{2};
            xcors{2} = tmp;
        end
                        
        [A,dist] = dsearchn(qrs1,qrs2);         % closest ref for each point in test qrs
        keepA = (dist<WIN);
        if any(keepA)
            tmpmat = [A(keepA) find(keepA)];
            [~,idx]=max([xcors{1}(tmpmat(:,1)), xcors{2}(tmpmat(:,2))],[],2);
            qrs1(tmpmat(idx ~= 1,1)) = [];
            qrs2(tmpmat(idx ~= 2,2)) = [];
        end
        if numel(qrs1)>numel(qrs2)
            qrs = qrs1;          
            ect_qrs = qrs2;
        else
            qrs = qrs2;          
            ect_qrs = qrs1;
        end
%     end
    
else
    qrs = qrs{1};
end


